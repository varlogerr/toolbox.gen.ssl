#!/usr/bin/env bash

THE_SCRIPT="$(basename "${BASH_SOURCE[0]}")"
TOOL_DIR="$(realpath "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/..")"

. "${TOOL_DIR}/core/vars.sh"

print_help_description() {
  while read -r l; do
    [[ -n "${l}" ]] && echo "${l}"
  done <<< "
    Generate options file.
  "
}
print_help_usage() {
  echo "Usage:"
  while read -r l; do
    [[ -n "${l}" ]] && echo "  ${l}"
  done <<< "
    ${THE_SCRIPT} [DESTINATION]
  "
}
print_help_opts() {
  echo "Options:"
  opts_template_to_help "${OPTS_OPTFILE}"
}
print_help_demo() {
  echo "Demo:"
  while read -r l; do
    [[ -n "${l}" ]] && echo "  ${l}"
  done <<< "
    # generate to stdout
    gen.ssl-optfile.sh
    # generate to ~/options/ssl-gen.conf file
    gen.ssl-optfile.sh > ~/options/ssl-gen.conf
    # generate to ~/options/ssl-gen.conf file.
    # ~/options directory will be created if doesn't exist
    gen.ssl-optfile.sh ~/options/ssl-gen.conf
  "
}

. "${TOOL_DIR}/core/func.sh"

parse_opts '
  -t|--type/type
' '
  -h|--help/help
' '' "${@}"

# vars required for bootstrap
AVAILABLE_OPTNAMES="$(opts_template_to_optnames "${OPTS_OPTFILE}")"

. "${TOOL_DIR}/core/bootstrap.sh"

all_opts="
  ${OPTS_CA}
  ${OPTS_CLIENT}
"

if [[ -n "${PARSED_OPTS_KV[type]}" ]]; then
  if ! grep -qPx 'ca|client' <<< "${PARSED_OPTS_KV[type]}"; then
    echo "Infalid value for --type"
    print_help_opts
    exit 1
  fi

  var_name="OPTS_${PARSED_OPTS_KV[type]^^}"
  all_opts="${!var_name}"
fi

all_opts="
  ${all_opts}
  ${OPTS_CA_CLIENT_COMMON}
"

optfile=
if [[ ${#PARSED_OPTS_POSITIONAL[@]} -gt 0 ]]; then
  optfile="${PARSED_OPTS_POSITIONAL[-1]}"
fi

optfile_content="$(
  opts_template_to_optfile \
    "${all_opts}" optfile "${optfile}"
)"

optfile="${optfile:-/dev/stdout}"

optfile_content="$(
  echo "##########"
  while read -r l; do
    [[ -z "${l}" ]] && continue
    output="#"
    [[ "${l:0:1}" != '*' ]] && output+="  "
    output+=" ${l}"
    echo "${output}"
  done <<< "
    * each line in the file to be in OPT=VAL format
    * lines starting with # and blank lines are
      ignored
    * blank lines are ignored
    * quotation marks are part of the VAL
    * inline options override the ones from the
      option file
    * there is no expansion for values from option
      files, i.e. ~ or \$(pwd) won't be processed
      as the home directory or current working
      directory
    * in option file context relative paths for
      \`ca-dir\` and \`client-dir\` are relative
      to the directory of the opionfile they are
      specified in
    * for flag options 0 or empty string to disable
      the flag and 1 to enable it
  "
  echo "##########"
  echo "${optfile_content}"
)"

echo "${optfile_content}" > "${optfile}"

# echo "KV >"
# for k in "${!PARSED_OPTS_KV[@]}"; do
#   echo "  ${k} = ${PARSED_OPTS_KV[${k}]}"
# done
# echo "Multi KV >"
# for k in "${!PARSED_OPTS_MULTI_KV[@]}"; do
#   echo "  ${k} = ${PARSED_OPTS_MULTI_KV[${k}]}"
# done
# echo "Positional >"
# for k in "${!PARSED_OPTS_POSITIONAL[@]}"; do
#   echo "  ${k} = ${PARSED_OPTS_POSITIONAL[${k}]}"
# done
