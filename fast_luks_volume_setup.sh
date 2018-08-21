#!/bin/bash

STAT="fast-luks-volume-setup"
LOGFILE="/tmp/luks_encryption.log"
#LOGFILE="/tmp/luks_encryption$(date +"-%b-%d-%y-%H%M%S").log"
SUCCESS_FILE="/tmp/fast-luks.success"

# lockfile configuration
LOCKDIR=/var/run/fast_luks
PIDFILE=${LOCKDIR}/fast-luks-encryption.pid

# Load functions
if [[ -f ./fast_luks_lib.sh ]]; then
  source ./fast_luks_lib.sh
else
  echo '[Error] No fast_luks_lib.sh file found.'
  exit 1
fi

# Check if script is run as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo_error "Not running as root."
    exit 1
fi

# Create lock file. Ensure only single instance running.
lock "$@"

# Start Log file
logs_info "Start log file: $(date +"%b-%d-%y-%H%M%S")"

# Loads defaults values then take user custom parameters.
load_default_config

# Parse CLI options
while [ $# -gt 0 ]
do
  case $1 in
    -d|--device) device="$2"; shift ;;

    -e|--cryptdev) cryptdev="$2"; shift ;;

    -m|--mountpoint) mountpoint="$2"; shift ;;

    -f|--filesystem) filesystem="$2"; shift ;;

    --paranoid-mode) paranoid=true;;

    --foreground) foreground=true;; # run script in foregrond, allowing to use it on ansible playbooks.

    --default) DEFAULT=YES;;

    -h|--help) print_help=true;;

    -*) echo >&2 "usage: $0 [--help] [print all options]"
        exit 1;;
    *) DEFAULT=YES;; # terminate while loop
  esac
  shift
done

if [[ -n "$1" ]]; then
    logs_info "Last line of file specified as non-opt/last argument:"
    tail -1 $1
fi

# Print Help
if [[ $print_help = true ]]; then
  echo ""
  usage="$(basename "$0"): a bash script to automate LUKS file system encryption.\n
         usage: fast-luks [-h]\n
         \n
         optionals argumets:\n
         -h, --help                   \t\tshow this help text\n
         -d, --device                 \t\tset device [default: /dev/vdb]\n
         -e, --cryptdev               \tset crypt device [default: cryptdev]\n
         -m, --mountpoint             \tset mount point [default: /export]\n
         -f, --filesystem             \tset filesystem [default: ext4]\n
         --paranoid-mode              \twipe data after encryption procedure. This take time [default: false]\n
         --foreground                 \t\trun script in foreground [default: false]\n
         --default                    \t\tload default values from defaults.conf\n"
  echo -e $usage
  logs_info "Just printing help."
  unlock
  exit 0
elif [[ ! -v print_help ]]; then
    info >> "$LOGFILE" 2>&1
fi

# Print intro
if [[ $non_interactive == false ]]; then intro; fi

# Unlock once done.
unlock >> "$LOGFILE" 2>&1