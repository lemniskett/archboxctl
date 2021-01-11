#!/usr/bin/env bash

SYSTEMD_UNITS_DIR="/usr/lib/systemd/system"

parse_exec() {
    where=$(grep --color=never "Exec$1=" /tmp/archbox/exec \
        | grep -bo "/" | sed -n 1p | sed 's/:.*$//')
    command=$(grep --color=never "Exec$1=" /tmp/archbox/exec)
    command=${command:$where}
    echo $command
}

help() {
cat << EOF
USAGE: $0 <options>

OPTIONS:
  list-units                Lists all usable units.
  desc, description ARGS    Prints a systemd service file.
  exec ARGS                 Runs a systemd service.
  log ARGS                  Views output of a service.
  help                      Shows this help.

EOF
}

err() {
    echo "$(tput setaf 1)$@$(tput sgr0)" 1>&2
    exit 1
}

asroot(){
    [[ $EUID -ne 0 ]] && err "Run this as root!"
}

case $1 in
    list-units)
        ls -1 $SYSTEMD_UNITS_DIR \
            | sed '/systemd/d;/.target/d;/.socket/d;/.slice/d;/.mount/d;/.timer/d'
        ;;
    desc|description)
        [[ -z $2 ]] && err "Expected an argument"
        cat $SYSTEMD_UNITS_DIR/$2.service
        ;;
    exec)
        asroot
        [[ -z $2 ]] && err "Expected an argument"
        cp $SYSTEMD_UNITS_DIR/$2.service /tmp/archbox/exec
        sed -i '/#/d' /tmp/archbox/exec
        mkdir -p /var/log/archboxctl/$2

        start_command=$(parse_exec Start)
        prestart_command=$(parse_exec StartPre)
        poststart_command=$(parse_exec StartPost)

        [[ ! -z $prestart_command ]] && \
            sh -c "$prestart_command" > /var/log/archboxctl/$2/pre_out.log \
            2> /var/log/archboxctl/$2/pre_err.log

        sh -c "$start_command" > /var/log/archboxctl/$2/out.log \
            2> /var/log/archboxctl/$2/err.log

        [[ ! -z $poststart_command ]] && \
            sh -c "$poststart_command" > /var/log/archboxctl/$2/post_out.log \
            2> /var/log/archboxctl/$2/post_err.log
        exit 0
        ;;
    log)
        [[ -z $2 ]] && err "Expected an argument"
        cat /var/log/archboxctl/$2/{out,err}.log
        ;;
    help)
        help
        ;;
    *)
        help 1>&2
        exit 1
        ;;
esac
