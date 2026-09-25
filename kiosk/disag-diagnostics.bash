# DietPi invokes dietpi-login from every interactive Bash shell. The
# diagnostic account must not attempt its privileged first-run setup.
[[ $(id -un) == svvdiag ]] && export G_DIETPI_LOGIN=1
