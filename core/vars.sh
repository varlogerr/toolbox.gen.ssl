#
# OPTS formag:
# <opt-pattern-started-with-at-least-one-hiphen>/<opt-name>
#
OPTS_OPTFILE="
  -t|--type/type
    Optionfile for ca or client. If not
    specified will be generated for both.
    Available values:
    * ca
    * client
    Example: --type ca
"
OPTS_CA_CLIENT_COMMON="
  --ca-dir/ca-dir
    CA certificates destination directory.
    Example: --ca-dir ~/certs
  --ca-file-prefix/ca-file-prefix
    CA files prefix.
    Example: --ca-file-prefix acme-
  --ca-phrase/ca-phrase
    CA pkey passphrase.
    Can also be provided with GEN_SSL_CA_PHRASE
    environment variable (lowest presedence).
    Example: --ca-phrase changeme
  --optfile/optfile
    File to read options from. Allowed
    multiple times. Inline options take
    precedense over the ones in optfiles.
    Example: --optfile ~/optfiles/mysite.conf
  -f|--force/force
    (flag) Override if certificates exist
  -s|--silent/silent
    (flag) Try to avoid interactions:
    * silently halt if certificates exist
"
OPTS_CA="
  --ca-cert-days/ca-cert-days
    CA certificate days.
    Example: --ca-cert-days 566
  --ca-cn/ca-cn
    CA common name.
    Example: --ca-cn Acme
"
OPTS_CLIENT="
  --client-cert-days/client-cert-days
    Client certificate days.
    Values greater than 365 should be avoided.
    Example: --client-cert-days 340
  --client-dir/client-dir
    Client certificates destination directory.
    Example: --client-dir ~/certs/client
  --client-cn/client-cn
    Client common name.
    Example: --client-cn '*.site.local'
  --client-filename/client-filename
    Client certificates file name (without
    extension). Defaults to --client-cn value
    with '*' replaced with '_'.
    Example: --client-filename localhost
  --merge/merge
    (flag) Merge key and crt into single *.crt file
"

declare -A OPTS_DEFAULT=(
  [ca-cert-days]=36500
  [ca-dir]=.
  [client-cert-days]=365
  [client-dir]=.
)
