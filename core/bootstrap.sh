#
# * print help
# * parse optfile
# * merge optfile KVs with inline KVs
# * validate --force and --silent flags
#

print_help() {
  local first=0

  for f in \
    print_help_description \
    print_help_usage \
    print_help_opts \
    print_help_demo \
  ; do
    [[ "$(type -t "${f}")" != 'function' ]] && continue
    [[ ${first} -gt 0 ]] && echo
    ${f}
    ((first++))
  done
}

opt_n=1
while :; do
  [[ -z "${!opt_n+x}" ]] && break

  opt="${!opt_n}"
  if : \
    && grep -Pxq -- '-h|-\?|--help' <<< "${opt}" \
    && [[ "$(type -t print_help)" == 'function' ]] \
  ; then
    print_help
    exit
  elif : \
    && grep -Pxq -- '--long-help' <<< "${opt}" \
    && [[ "$(type -t print_help_long)" == 'function' ]] \
  ; then
    print_help_long
    exit
  elif : \
    && grep -Pxq -- '--short-help' <<< "${opt}" \
    && [[ "$(type -t print_help_short)" == 'function' ]] \
  ; then
    print_help_short
    exit
  fi

  (( opt_n++ ))
done

{ # validate required variables
  absent_vars=()
  for v in \
    AVAILABLE_OPTNAMES \
  ; do
    the_var="${!v}"
    if [[ -z "${the_var}" ]]; then
      absent_vars+=("${v}")
    fi
  done
  if [[ ${#absent_vars[@]} -gt 0 ]]; then
    echo "Absent vars:"
    for v in "${absent_vars[@]}"; do
      echo "  * ${v}"
    done
    exit 1
  fi
}

{ # parse optfiles
  optfiles="$(
    tr ' ' $'\n' <<< "${!PARSED_OPTS_MULTI_KV[@]}" \
    | grep -Px 'optfile\.\d+' | sort -V \
    | while read -r k; do
      echo "${PARSED_OPTS_MULTI_KV[${k}]}"
    done
  )"

  if [[ -n "${optfiles}" ]]; then
    invalid_files=()
    IFS_KEEP="${IFS}"; IFS=$'\n';
    for of in ${optfiles}; do
      IFS="${IFS_KEEP}"

      if [[ ! -f "${of}" ]]; then
        invalid_files+=("${of}")
        continue
      fi

      parse_optfile "${of}" 'ca-dir client-dir'
    done

    if [[ ${#invalid_files[@]} -gt 0 ]]; then
      echo 'Invalid optfiles:'
      for f in "${invalid_files[@]}"; do
        echo "  * ${f}"
      done
      exit 1
    fi
  fi
}

merge_kv_and_optfile_opts

{ # filter out only required opts
  parsed_optnames_list="$(tr ' ' $'\n' <<< "${!PARSED_OPTS_KV[@]}")"
  avail_optnames_rex="$(printf '%s' "${AVAILABLE_OPTNAMES}" | tr $'\n' '|')"
  rm_optnames="$(grep -Pvx "(${avail_optnames_rex})" <<< "${parsed_optnames_list}")"
  for to_rm in ${rm_optnames}; do
    unset PARSED_OPTS_KV[${to_rm}]
  done
}

{ # validate --force and --silent flags
  if \
    [[ ${PARSED_OPTS_KV[force]} == 1 ]] \
    && [[ ${PARSED_OPTS_KV[force]} == ${PARSED_OPTS_KV[silent]} ]] \
  ; then
    echo "--force and --silent are not allowed together"
    exit
  fi
}

{ # apply defaults (avoid optfile)
  while read -r o; do
    PARSED_OPTS_KV[${o}]="${PARSED_OPTS_KV[${o}]:-${OPTS_DEFAULT[${o}]}}"
  done <<< $(grep -v 'optfile' <<< "${AVAILABLE_OPTNAMES}")
}

{ # try to get CA phrase env variable if not set yet
  if [[ -z "${PARSED_OPTS_KV[ca-phrase]}" ]]; then
    PARSED_OPTS_KV[ca-phrase]="${GEN_SSL_CA_PHRASE}"
  fi
}
