declare -A PARSED_OPTS_KV=()
declare -A PARSED_OPTS_MULTI_KV=()
declare PARSED_OPTS_POSITIONAL=()
declare -A PARSED_OPTFILE=()
# Usage:
#   parse_opts "
#     --kv_opt1/kv_opt1_name
#     -k2|--kv_opt2/kv_opt2_name
#   " "
#     --flag1/flag1_name
#     -f2|--flag2/flag2_name
#   " "
#     --multi_kv_opt1/multi_kv_opt1_name
#     -m2|--multi_kv_opt2/multi_kv_opt2_name
#   " "${@}"
parse_opts() {
  local endofopt=0
  local available_opts_kv="$(_opts_lst_str_normalize "${1}")"
  local available_opts_flag="$(_opts_lst_str_normalize "${2}")"
  local available_opts_multi="$(_opts_lst_str_normalize "${3}")"
  shift
  shift
  shift
  local available_opts_kv_and_multi="$(
    _opts_lst_str_normalize \
    "$(printf '%s\n%s' "${available_opts_kv}" "${available_opts_multi}")"
  )"

  local kv_rex="$(_opts_lst_str_to_rex "${available_opts_kv}")"
  local flag_rex="$(_opts_lst_str_to_rex "${available_opts_flag}")"
  local multi_rex="$(_opts_lst_str_to_rex "${available_opts_multi}")"
  local kv_and_multi_rex="$(_opts_lst_str_to_rex "${available_opts_kv_and_multi}")"

  while :; do
    # break if no more opts
    [[ -z "${1+x}" ]] && break

    local the_opt="${1}"
    shift

    if \
      [[ "${the_opt:0:1}" != '-' ]] \
      || [[ ${endofopt} -ne 0 ]] \
    ; then
      # positional
      PARSED_OPTS_POSITIONAL+=("${the_opt}")
      continue
    fi

    if [[ "${the_opt}" == '--' ]]; then
      # endofopts
      endofopt=1
      continue
    fi

    if \
      grep -Pxq -- "(${kv_and_multi_rex})(=.*)?" <<< "${the_opt}" \
    ; then
      # kv or multi option
      if grep -Pxq -- "(${kv_rex})=.*" <<< "${the_opt}"; then
        # `--opt=value` format
        local kv="${the_opt}"
        local val="${kv#*=}"
        local optkey="${kv%%=*}"
      else
        # `--opt value` format
        local optkey="${the_opt}"
        local val="${1}"
        shift
      fi

      local optkey_rex='([^\|]+\|)?('${optkey}')(\|[^\|]+)?\/.*'
      local optname_entry="$(grep -Px -- "${optkey_rex}" <<< "${available_opts_kv_and_multi}")"
      local optname="${optname_entry##*"/"}"

      if grep -Pxq -- "${optkey_rex}" <<< "${available_opts_kv}"; then
        # kv option
        PARSED_OPTS_KV[${optname}]="${val}"
      elif grep -Pxq -- "${optkey_rex}" <<< "${available_opts_multi}"; then
        # multi-kv option
        local last_num="$(
          for k in "${!PARSED_OPTS_MULTI_KV[@]}"; do
            echo "${k}"
          done | grep -Px -- ${optname}'.\d+' \
          | sort -n | tail -n 1 | rev | cut -d. -f1
        )"

        local new_num=1
        [[ -n "${last_num}" ]] && new_num=$((last_num + 1))

        PARSED_OPTS_MULTI_KV[${optname}.${new_num}]="${val}"
      fi

      continue
    fi

    if grep -Pxq -- "(${flag_rex})" <<< "${the_opt}"; then
      # flag
      local optkey_rex='([^\|]+\|)?('${the_opt}')(\|[^\|]+)?\/.*'
      local optname_entry="$(grep -Px -- "${optkey_rex}" <<< "${available_opts_flag}")"
      local optname="${optname_entry##*"/"}"
      PARSED_OPTS_KV[${optname}]=1
    fi
  done
}

parse_optfile() {
  local optfile="${1}"
  local pathvars="${2}"

  while read -r l; do
    [[ -z "${l}" ]] && continue
    local optname="$(cut -d= -f1 <<< "${l}")"
    local optval="$(cut -d= -f2 <<< "${l}")"
    if \
      [[ " ${pathvars} " == *" ${optname} "* ]] \
      && [[ "${optval:0:1}" != "/" ]] \
    ; then
      # translate to path relative to the current optfile
      local optfile_dir="$(
        dirname "$(realpath "${optfile}")"
      )"
      optval="${optfile_dir}/${optval}"
    fi

    PARSED_OPTFILE[${optname}]="${optval}"
  done <<< "$(while read -r l; do
    [[ -n "${l}" ]] && echo "${l}"
  done < "${optfile}" \
  | grep -Pv '^#' | grep -P '.+=.*')"
}

opts_template_to_help() {
  local opts="${1}"

  while read -r l; do
    [[ -z "${l}" ]] && continue
    [[ "${l:0:1}" != '-' ]] && echo "    ${l}" && continue

    local optkey="$(cut -d'/' -f1 <<< "  ${l}" | sed 's/|/, /g')"
    local optname="$(cut -d'/' -f2 <<< "${l}")"
    if [[ -n "${OPTS_DEFAULT[${optname}]}" ]]; then
      optkey+=" (default: ${OPTS_DEFAULT[${optname}]})"
    fi
    echo "${optkey}"
  done <<< "${opts}"
}

opts_template_to_optfile() {
  local opts="${1}"
  local exclude_optnames="${2}"
  local optfile="${3}"

  declare -A opt_to_desciprtion=()
  local optname=
  while read -r l; do
    if [[ "${l:0:1}" == '-' ]]; then
      optname="$(cut -d'/' -f2 <<< "${l}")"
      opt_to_desciprtion[${optname}]=
      continue
    fi

    if [[ -n "${l}" ]] && [[ -n "${optname}" ]]; then
      if [[ -n "${opt_to_desciprtion[${optname}]}" ]]; then
        opt_to_desciprtion[${optname}]+=$'\n'
      fi
      opt_to_desciprtion[${optname}]+="# ${l}"
    fi
  done <<< "${opts}"

  if [[ -f "${optfile}" ]]; then
    parse_optfile "${optfile}"
  fi

  for opt in "${!opt_to_desciprtion[@]}"; do
    echo "${opt}"
  done | sort | uniq | while read -r optname; do
    if [[ " ${exclude_optnames} " == *" ${optname} "* ]]; then
      continue
    fi

    echo

    description="${opt_to_desciprtion[${optname}]}"
    if [[ -n "${OPTS_DEFAULT[${optname}]}" ]]; then
      [[ -n "${description}" ]] && description+=$'\n'
      description+="# Default: ${OPTS_DEFAULT[${optname}]}"
    fi
    [[ -n "${description}" ]] && echo "${description}"

    print_opt="${optname}="
    if [[ -n "${PARSED_OPTFILE[${optname}]+x}" ]]; then
      print_opt+="${PARSED_OPTFILE[${optname}]}"
    elif [[ -n "${OPTS_DEFAULT[${optname}]}" ]]; then
      print_opt+="${OPTS_DEFAULT[${optname}]}"
    fi

    echo "${print_opt}"
  done
}

opts_template_to_optnames() {
  local opts="${1}"

  while read -r l; do
    [[ -n "${l}" ]] && echo "${l}"
  done <<< "${opts}" \
  | grep -P -- '^\-' | cut -d'/' -f2
}

merge_kv_and_optfile_opts() {
  for k in "${!PARSED_OPTFILE[@]}"; do
    if [[ -z "${PARSED_OPTS_KV[${k}]}" ]]; then
      PARSED_OPTS_KV[${k}]="${PARSED_OPTFILE[${k}]}"
    fi
  done
}

_opts_lst_str_normalize() {
  local opts_lst="${1}"

  while read -r l; do
    [[ -n "${l}" ]] && echo "${l}";
  done <<< "${opts_lst}"
}

_opts_lst_str_to_rex() {
  local opts_lst="${1}"

  printf -- '%s' "$(cut -d'/' -f 1 <<< "${opts_lst}")" \
  | tr '\n' '|'
}
