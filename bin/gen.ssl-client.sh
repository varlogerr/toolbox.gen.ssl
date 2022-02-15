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
    Generate based on CA client certificate.
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
    ${OPTS_CLIENT}
    ${OPTS_CA_CLIENT_COMMON}
  "
}

. "${TOOL_DIR}/core/func.sh"

parse_opts '
  --client-cert-days/client-cert-days
  --client-dir/client-dir
  --client-cn/client-cn
  --client-filename/client-filename
  --ca-dir/ca-dir
  --ca-file-prefix/ca-file-prefix
  --ca-phrase/ca-phrase
' '
  -h|--help/help
  -f|--force/force
  -s|--silent/silent
  --merge/merge
' '
  --optfile/optfile
' "${@}"

# vars required for bootstrap
AVAILABLE_OPTNAMES="$(opts_template_to_optnames "
  ${OPTS_CLIENT}
  ${OPTS_CA_CLIENT_COMMON}
")"
GEN_FILES=(.key .csr .ext .crt)

# up to here

. "${TOOL_DIR}/core/bootstrap.sh"

CA_FILEPATH="${PARSED_OPTS_KV[ca-dir]}/${PARSED_OPTS_KV[ca-file-prefix]}ca"

{ # validate ca files
  unreadable="$(
    for ext in .crt .key; do
      check_file="${CA_FILEPATH}${ext}"
      [[ ! -r "${check_file}" ]] && echo "${check_file}"
    done
  )"

  if [[ -n "${unreadable}" ]]; then
    echo "The following files can't be accessed:"
    while read -r f; do echo "  * ${f}"; done <<< "${unreadable}"
    echo "Make sure they exist and are readable by the current user!"
    exit 1
  fi
}

{ # ensure common name
  while :; do
    [[ -n "${PARSED_OPTS_KV[client-cn]}" ]] && break

    read -p 'Client CN (for example *.site.local): ' client_cn
    [[ -z "${client_cn}" ]] && echo "Can't be blank"
    PARSED_OPTS_KV[client-cn]="${client_cn}"
  done
}

PARSED_OPTS_KV[client-filename]="${PARSED_OPTS_KV[client-filename]:-$(sed 's/\*/_/' <<< "${PARSED_OPTS_KV[client-cn]}")}"

{ # check existing cert files
  existing_files=()
  for ending in "${GEN_FILES[@]}"; do
    check_file="${PARSED_OPTS_KV[client-dir]}/${PARSED_OPTS_KV[client-filename]}${ending}"
    
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

{ # ensure ca phrase
  ctr=0
  while test -z "${PARSED_OPTS_KV[ca-phrase]}" \
    || ! openssl rsa \
      -passin file:<( ca_phrase="${PARSED_OPTS_KV[ca-phrase]}" printenv ca_phrase ) \
      -in "${CA_FILEPATH}.key" > /dev/null 2>&1\
  ; do
    [[ "${ctr}" -gt 0 ]] && echo "Invalid CA Phrase!"
    read -sp 'CA Phrase: ' ca_phrase
    echo
    PARSED_OPTS_KV[ca-phrase]="${ca_phrase}"
    ((ctr++))
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

CLIENT_DIR="${PARSED_OPTS_KV['client-dir']}"
[[ ! -d "${CLIENT_DIR}" ]] && mkdir -p "${CLIENT_DIR}"

CLIENT_CN="${PARSED_OPTS_KV['client-cn']}"

CLIENT_FILEPATH="$(realpath "${CLIENT_DIR}/${PARSED_OPTS_KV['client-filename']}")"
EXTFILE_PATH="${CLIENT_FILEPATH}.ext"
KEYFILE_PATH="${CLIENT_FILEPATH}.key"
CSRFILE_PATH="${CLIENT_FILEPATH}.csr"
CRTFILE_PATH="${CLIENT_FILEPATH}.crt"

echo "> Generate ${EXTFILE_PATH}"
{
  extfile_line="DNS.1 = ${CLIENT_CN}"
  if grep -Pq '^(\d{1,3}\.){3}\d{1,3}$' <<< ${CLIENT_CN}; then
    extfile_line="IP.1 = ${CLIENT_CN}"
  fi

  while read -r l; do [[ -n "${l}" ]] && echo "${l}"; done <<< "
    authorityKeyIdentifier=keyid,issuer
    basicConstraints=CA:FALSE
    keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = @alt_names
    [alt_names]
    ${extfile_line}
    ## domain or domain mask for DNS
    # DNS.1 = domain.local
    # DNS.2 = *.domain.local
    ## IP
    # IP.1 = 10.134.88.11
    # IP.2 = 192.168.0.55
  " > "${EXTFILE_PATH}"
}

echo "> Generate ${KEYFILE_PATH}"
openssl genpkey -algorithm RSA -outform PEM \
  -pkeyopt rsa_keygen_bits:4096 -out "${KEYFILE_PATH}"

echo "> Generate ${CSRFILE_PATH}"
openssl req -new -key "${KEYFILE_PATH}" \
  -subj "/CN=${CLIENT_CN}" \
  -out "${CSRFILE_PATH}"

echo "> Generate ${CRTFILE_PATH}"
openssl x509 -req -in "${CSRFILE_PATH}" \
  -CA "${CA_FILEPATH}.crt" \
  -CAkey "${CA_FILEPATH}.key" \
  -extfile "${EXTFILE_PATH}" \
  -CAcreateserial -days "${PARSED_OPTS_KV[client-cert-days]}" -sha256 \
  -passin file:<( ca_phrase="${PARSED_OPTS_KV[ca-phrase]}" printenv ca_phrase ) \
  -out "${CRTFILE_PATH}"

if [[ ${PARSED_OPTS_KV[merge]} -eq 1 ]]; then
  echo "> Merge KEY into ${CRTFILE_PATH}"
  chmod 0600 "${CRTFILE_PATH}"
  cat "${KEYFILE_PATH}" >> "${CRTFILE_PATH}"
  rm -f "${KEYFILE_PATH}"
fi

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
