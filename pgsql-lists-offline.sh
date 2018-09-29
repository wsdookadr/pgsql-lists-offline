#!/bin/bash
USER=archives
PASS=antispam

help() {
    echo "
Usage: pgsql-lists-offline.sh <params>

-l get a list of all mailing lists
-g <mailing-list-name> get all archives from a certain mailing list

"
}

list_all() {
    curl -s "https://www.postgresql.org/list/" | \
    perl -ne 'm{"/list/(pgsql.*?)/"} && print "$1\n"; ' | \
    sort | \
    uniq
}

sync_ml() {
    NAME=$1
    declare -a MBOX_PATHS=( $(curl -s https://www.postgresql.org/list/$NAME/ | grep "/mbox/" | perl -ne 'm{href="(/list/.*?)"} && print "$1\n"') )

    for MP in "${MBOX_PATHS[@]}"; do
        # MP is a relative url to the mbox file
        # MF is just the file name for the mbox
        MF=$(echo "$MP" | perl -ne 'm{([^\/]+)$} && print "$1\n"')
        if [[ ! -f "data/$MF" ]]; then
            echo "$MP,$MF"
        fi
    done | \
    USER="$USER" PASS="$PASS" parallel  --no-notice --col-sep , -j4 -k 'curl -s --user $USER:$PASS "https://www.postgresql.org{1}" -o data/{2} ; echo {2};'
}

NO_PARAMS=1

while getopts ":lg:" opt; do
  case $opt in
    l)
      list_all
      NO_PARAMS=0
      ;;
    g)
      echo "$OPTARG"
      mkdir data
      sync_ml "$OPTARG"
      NO_PARAMS=0
      ;;
    *)
      help;
      ;;
  esac
done

if [[ "$NO_PARAMS" -eq "1" ]]; then
    help;
    exit 0;
fi

