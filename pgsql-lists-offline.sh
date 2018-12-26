#!/bin/bash
PGSQL_USER=archives
PGSQL_PASS=antispam

help() {
    echo "
Usage: pgsql-lists-offline.sh <params>

-l list the mailing lists supported for download
-g <mailing-list-name> get all archives from a certain mailing list
-c generates archives for each mailing list
"
}

# This function lists all the archives supported for download.
list_all() {
    curl -s "https://www.postgresql.org/list/" | \
    perl -ne 'm{"/list/(pgsql.*?)/"} && print "$1\n"; ' | \
    sort | \
    uniq

    echo "postgis-devel"
    echo "postgis-users"
    echo "postgis-tickets"
    echo "pgrouting-dev"
    echo "pgrouting-users"
}


#
# The email archive is usually composed of one compressed file per month
# containing all the emails sent to the mailing list for that month.
# 
# This function downloads all of them.
#
# Input: mailing list name
#
sync_ml() {
    NAME=$1

    mkdir -p data/$NAME/

    # This array holds all the urls to the archives that will be
    # downloaded.
    declare -a DOWNLOAD_LINKS=()

    if [[ "$NAME"   =~ ^postgis.* ]] || [[ "$NAME" =~ ^pgrouting.* ]]; then
        # osgeo mailing lists
        DOWNLOAD_LINKS=( $(curl -s https://lists.osgeo.org/pipermail/$NAME/ | perl -ne 'm{href="(\d{4}.*?.txt.gz)} && print "$1\n"' ) )
    elif [[ "$NAME" =~ ^pgsql.* ]]; then
        # postgresql mailing lists
        DOWNLOAD_LINKS=( $(curl -s https://www.postgresql.org/list/$NAME/ | grep "/mbox/" | perl -ne 'm{href="(/list/.*?)"} && print "$1\n"') )
    else
        echo "[Error] Sorry, there's no logic to download the $NAME mailing list."
        exit 1
    fi

    for MP in "${DOWNLOAD_LINKS[@]}"; do
        # MP is a relative url to the archive file
        # MF is just the archive file name
        MF=$(echo "$MP" | perl -ne 'm{([^\/]+)$} && print "$1\n"')
        
        # if the archive is absent from disk, download it
        if [[ ! -f "data/$NAME/$MF" ]]; then

            if [[ "$NAME"   =~ ^postgis.* ]] || [[ "$NAME" =~ ^pgrouting.* ]]; then
                CURL_CMD="curl -s \"https://lists.osgeo.org/pipermail/$NAME/$MP\" -o data/$NAME/$MF ; echo \"$MF\";"
            elif [[ "$NAME" =~ ^pgsql.* ]]; then
                CURL_CMD="curl -s --user $PGSQL_USER:$PGSQL_PASS \"https://www.postgresql.org$MP\" -o data/$NAME/$MF ; echo \"$MF\";"
            fi

            echo "$CURL_CMD"
        fi
    done | \
    parallel --no-notice --col-sep , -j4 '{}'
}

NO_PARAMS=1

while getopts ":lg:ch" opt; do
  case $opt in
    l)
      list_all
      NO_PARAMS=0
      exit 0
      ;;
    g)
      echo "$OPTARG"
      mkdir data
      sync_ml "$OPTARG"
      NO_PARAMS=0
      exit 0
      ;;
    c)
      mkdir packed
      ls data | parallel --no-notice -j3 '
        cd data
        rm ../packed/{}.tar.gz
        tar czvf ../packed/{}.tar.gz {}/
      '
      exit 0
      ;;
    h)
      help;
      exit 0;
      ;;
    *)
      help;
      ;;
  esac
done

