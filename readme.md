# SSL gen tool

Old and naive set of scripts for self-signed ssl certificates generation. Not (or rarely?) supported as [mkcert](https://github.com/FiloSottile/mkcert) is a much better alternative.

## Installation

```sh
# clone the repository
sudo git clone https://github.com/varlogerr/toolbox.gen.ssl.git /opt/varlog/toolbox.gen.ssl
# check pathadd.append function is installed
type -t pathadd.append
# in case output is "function" you can make use
# of pathadd-based bash hook. Otherwise add
# '/opt/varlog/toolbox.gen.ssl/bin' directory
# to the PATH manually
echo '. /opt/varlog/toolbox.gen.ssl/hook-pathadd.bash' >> ~/.bashrc
# reload ~/.bashrc
. ~/.bashrc
# explore the scripts
gen.ssl-optfile.sh -h
gen.ssl-ca.sh -h
gen.ssl-client.sh -h
```

## References

* [`pathadd` tool](https://github.com/varlogerr/toolbox.pathadd)
