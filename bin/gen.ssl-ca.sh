#!/usr/bin/env bash

THE_SCRIPT="$(basename "${BASH_SOURCE[0]}")"
TOOL_DIR="$(realpath "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/..")"

. "${TOOL_DIR}/core/vars.sh"

print_help_description() {
  while read -r l; do
    [[ -z "${l}" ]] && continue
    [[ "${l:0:1}" == '*' ]] && echo "  ${l}" && continue
    echo "${l}"
  done <<< "
    Generate CA certificate.
    Manual steps after generation:
    * Chrome: chrome://settings/certificates > 'Authorities' tab
  "
}
print_help_usage() {
  echo "Usage:"
  while read -r l; do
    [[ -n "${l}" ]] && echo "  ${l}"
  done <<< "
    ${THE_SCRIPT} [OPTIONS]
    ${THE_SCRIPT} --optfile <option-file> [OPTIONS]
  "
}
print_help_opts() {
  echo "Options:"
  opts_template_to_help "
    ${OPTS_CA}
    ${OPTS_CA_CLIENT_COMMON}
  "
}

. "${TOOL_DIR}/core/func.sh"

parse_opts '
  --ca-cert-days/ca-cert-days
  --ca-cn/ca-cn
  --ca-dir/ca-dir
  --ca-file-prefix/ca-prefix
  --ca-phrase/ca-phrase
' '
  -h|--help/help
  -f|--force/force
  -s|--silent/silent
' '
  --optfile/optfile
' "${@}"

# vars required for bootstrap
AVAILABLE_OPTNAMES="$(opts_template_to_optnames "
  ${OPTS_CA}
  ${OPTS_CA_CLIENT_COMMON}
")"
GEN_FILES=(ca.key ca.crt)

. "${TOOL_DIR}/core/bootstrap.sh"

{ # check existing cert files
  existing_files=()
  for ending in "${GEN_FILES[@]}"; do
    check_file="${PARSED_OPTS_KV[ca-dir]}/${PARSED_OPTS_KV[ca-file-prefix]}${ending}"
    
    [[ -f "${check_file}" ]] && existing_files+=("${check_file}")
  done

  if [[ ${#existing_files[@]} -gt 0 ]] && [[ ${PARSED_OPTS_KV[force]} -ne 1 ]]; then
    echo "The following files already exist:"
    for f in "${existing_files[@]}"; do
      echo "  * ${f}"
    done

    if [[ ${PARSED_OPTS_KV[silent]} -eq 1 ]]; then
      echo "Exiting"
      exit
    fi

    while :; do
      read -p 'Override existing files? (y/N) ' override
      [[ -z "${override}" ]] && override=N

      if [[ "${override}" =~ ^[Yy]$ ]]; then
        PARSED_OPTS_KV[force]=1
        break
      fi
      if [[ "${override}" =~ ^[Nn]$ ]]; then
        exit
      fi

      override=''
    done
  fi
}

{ # ensure phrase
  ca_phrase="${PARSED_OPTS_KV[ca-phrase]}"
  ctr=0
  while :; do
    openssl genpkey -algorithm RSA -aes256 \
      -outform PEM -pkeyopt rsa_keygen_bits:1024 \
      -pass file:<( ca_phrase="${ca_phrase}" printenv ca_phrase ) \
      > /dev/null 2>&1
    pass_is_good=${?}

    if [[ -z "${ca_phrase}" ]] && [[ ${ctr} -gt 0 ]]; then
      echo "Phrase is blank!" > /dev/stderr
    elif [[ ${pass_is_good} -gt 0 ]] && [[ ${ctr} -gt 0 ]]; then
      echo "Phrase is invalid!" > /dev/stderr
    elif [[ -n "${ca_phrase}" ]] && [[ ${pass_is_good} -eq 0 ]]; then
      break
    fi

    ((ctr++))

    read -sp 'CA Phrase: ' ca_phrase
    echo
    [[ -z "${ca_phrase}" ]] && continue
    read -sp 'Confirm phrase: ' confirm_ca_phrase
    echo
    if [[ "${ca_phrase}" != "${confirm_ca_phrase}" ]]; then
      ca_phrase=
      ctr=0
      echo "Phrase doesn't match confirm"
      continue
    fi
  done
  PARSED_OPTS_KV[ca-phrase]="${ca_phrase}"
}

{ # ensure common name
  while :; do
    [[ -n "${PARSED_OPTS_KV[ca-cn]}" ]] && break

    read -p 'CA CN (for example Acme): ' ca_cn
    [[ -z "${ca_cn}" ]] && echo "Can't be blank"
    PARSED_OPTS_KV[ca-cn]="${ca_cn}"
  done
}

echo '==== OPTIONS ===='
for o in "${!PARSED_OPTS_KV[@]}"; do
  val="${PARSED_OPTS_KV[${o}]}"
  if [[ "${o}" == 'ca-phrase' ]]; then
    val="$(sed 's/./\*/g' <<< "${val}")"
  fi
  echo "${o} = ${val}"
done
echo '================='

ca_dir="${PARSED_OPTS_KV[ca-dir]}"
if [[ ! -d "${ca_dir}" ]]; then
  echo "> Create ${ca_dir} directory"
  mkdir -p "${ca_dir}"
fi

file_realpath="$(realpath "${ca_dir}/${PARSED_OPTS_KV[ca-file-prefix]}ca")"
key_file="${file_realpath}.key"
crt_file="${file_realpath}.crt"

echo "> Generate ${key_file}"
openssl genpkey -algorithm RSA -aes256 -outform PEM -pkeyopt rsa_keygen_bits:4096 \
  -pass file:<( ca_phrase="${PARSED_OPTS_KV[ca-phrase]}" printenv ca_phrase ) \
  -out "${key_file}"

ca_cn="${PARSED_OPTS_KV[ca-cn]}"
echo "> Generate ${crt_file}"
openssl req -x509 -new -nodes -sha512 -days "${PARSED_OPTS_KV[ca-cert-days]}" \
  -key "${key_file}" \
  -passin file:<( ca_phrase="${PARSED_OPTS_KV[ca-phrase]}" printenv ca_phrase ) \
  -subj "/O=${ca_cn} Org/OU=${ca_cn} Unit/CN=${ca_cn}" \
  -out "${crt_file}"


# echo "KV >"
# for k in "${!PARSED_OPTS_KV[@]}"; do
#   echo "  ${k} = ${PARSED_OPTS_KV[${k}]}"
# done
# echo "Multi KV >"
# for k in "${!PARSED_OPTS_MULTI_KV[@]}"; do
#   echo "  ${k} = ${PARSED_OPTS_MULTI_KV[${k}]}"
# done | sort -V
# echo "Positional >"
# for k in "${!PARSED_OPTS_POSITIONAL[@]}"; do
#   echo "  ${k} = ${PARSED_OPTS_POSITIONAL[${k}]}"
# done
