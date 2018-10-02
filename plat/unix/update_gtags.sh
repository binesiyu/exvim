#!/bin/sh

set -e

PROG_NAME=$0
GTAGS_EXE=gtags
GTAGS_ARGS=
TAGS_FILE=gtags
PROJECT_ROOT=
TARGET_ROOT=
FILE_LIST_CMD=
FILE_LIST_CMD_IS_ABSOLUTE=0
UPDATED_SOURCE=
POST_PROCESS_CMD=
PAUSE_BEFORE_EXIT=0


ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=gtags]: The gtags executable to run"
    echo "    -p [dir=]:      The path to the project root"
    echo "    -l [file=]:     The path to a log file"
    echo "    -L [cmd=]:      The file list command to run"
    echo "    -A:             Specifies that the file list command returns "
    echo "                    absolute paths"
    echo "    -x [pattern=]:  A pattern of files to exclude"
    echo "    -O [params=]:   Parameters to pass to gtags"
    echo "    -c:             Ask for confirmation before exiting"
    echo ""
}


while getopts "h?e:t:T:p:L:O:P:cA" opt; do
    case $opt in
        h|\?)
            ShowUsage
            exit 0
            ;;
        e)
            GTAGS_EXE=$OPTARG
            ;;
        t)
            TAGS_FILE=$OPTARG
            ;;
        T)
            TARGET_ROOT=$OPTARG
            ;;
        p)
            PROJECT_ROOT=$OPTARG
            ;;
        L)
            FILE_LIST_CMD=$OPTARG
            ;;
        A)
            FILE_LIST_CMD_IS_ABSOLUTE=1
            ;;
        c)
            PAUSE_BEFORE_EXIT=1
            ;;
        O)
            GTAGS_ARGS="$GTAGS_ARGS $OPTARG"
            ;;
        P)
            POST_PROCESS_CMD=$OPTARG
            ;;
    esac
done

shift $((OPTIND - 1))

if [ "$1" != "" ]; then
    echo "Invalid Argument: $1"
    exit 1
fi

echo "Locking gtags file..."
echo $$ > "$TAGS_FILE.lock"

# Remove lock and temp file if script is stopped unexpectedly.
# trap 'errorcode=$?; rm -f "$TAGS_FILE.lock" "$TAGS_FILE.files" "$TAGS_FILE.temp"; exit $errorcode' INT QUIT TERM EXIT


if [ -n "${FILE_LIST_CMD}" ]; then
    if [ "${PROJECT_ROOT}" = "." ] || [ $FILE_LIST_CMD_IS_ABSOLUTE -eq 1 ]; then
        eval $FILE_LIST_CMD > "${TAGS_FILE}.files"
    else
        # If using a gtags cache directory, use absolute paths
        eval $FILE_LIST_CMD | while read -r l; do
        echo "${PROJECT_ROOT%/}/${l}"
        done > "${TAGS_FILE}.files"
    fi
    # GTAGS_ARGS="-v -w -f ${TAGS_FILE}.files ${GTAGS_ARGS}"
    GTAGS_ARGS="-f ${TAGS_FILE}.files ${GTAGS_ARGS}"
    # Clear project root if we have a file list
fi
echo "Running gtags on whole project"
echo "$GTAGS_EXE  $GTAGS_ARGS $TARGET_ROOT"
echo "$GTAGSDBPATH $GTAGSROOT"

$GTAGS_EXE $GTAGS_ARGS $TARGET_ROOT

echo "Unlocking gtags file..."
rm -f "$TAGS_FILE.lock"

echo "Done."

if [ $PAUSE_BEFORE_EXIT -eq 1 ]; then
    printf "Press ENTER to exit..."
    read -r
fi
