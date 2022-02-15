[[ -n "${BASH_VERSION}" ]] && {
  __iife() {
    unset __iife
    local projdir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

    [[ "$(type -t pathadd.append)" != 'function' ]] && return

    GEN_SSL_BINDIR="${GEN_SSL_BINDIR:-${projdir}/bin}"
    [[ -z "$(bash -c 'echo ${GEN_SSL_BINDIR+x}')" ]] \
      && export GEN_SSL_BINDIR

    pathadd.append "${GEN_SSL_BINDIR}"
  } && __iife
}
