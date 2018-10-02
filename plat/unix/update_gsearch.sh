#!/bin/sh

set -e

PROG_NAME=$0
GSEARCH_EXE=mkid
GSEARCH_ARGS=
TAGS_FILE=ID
LAND_MAP=
PROJECT_ROOT=
LOG_FILE=
FILE_LIST_CMD=
FILE_LIST_CMD_IS_ABSOLUTE=0
UPDATED_SOURCE=
POST_PROCESS_CMD=
PAUSE_BEFORE_EXIT=0

ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=mkid]: The mkid executable to run"
    echo "    -t [file=ID]: The path to the mkid file to update"
    echo "    -p [dir=]:      The path to the project root"
    echo "    -l [file=]:     The path to a log file"
    echo "    -L [cmd=]:      The file list command to run"
    echo "    -A:             Specifies that the file list command returns "
    echo "                    absolute paths"
    echo "    -O [params=]:   Parameters to pass to mkid"
    echo "    -P [cmd=]:      Post process command to run on the ID file"
    echo "    -c:             Ask for confirmation before exiting"
    echo ""
}


while getopts "h?e:m:t:p:l:L:O:P:cA" opt; do
    case $opt in
        h|\?)
            ShowUsage
            exit 0
            ;;
        e)
            GSEARCH_EXE=$OPTARG
            ;;
        t)
            TAGS_FILE=$OPTARG
            ;;
        p)
            PROJECT_ROOT=$OPTARG
            ;;
        l)
            LOG_FILE=$OPTARG
            ;;
        m)
            LAND_MAP=$OPTARG
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
            GSEARCH_ARGS="$GSEARCH_ARGS $OPTARG"
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

echo "Locking ID file..."
echo $$ > "$TAGS_FILE.lock"

# Remove lock and temp file if script is stopped unexpectedly.
trap 'errorcode=$?; rm -f "$TAGS_FILE.lock" "$TAGS_FILE.files" "$TAGS_FILE.temp"; exit $errorcode' INT QUIT TERM EXIT

echo "Running mkid on whole project"
if [ -n "${FILE_LIST_CMD}" ]; then
    # if [ "${PROJECT_ROOT}" = "." ] || [ $FILE_LIST_CMD_IS_ABSOLUTE -eq 1 ]; then
    #     eval $FILE_LIST_CMD > "${TAGS_FILE}.files"
    # else
    #     # If using a ID cache directory, use absolute paths
    #     eval $FILE_LIST_CMD | while read -r l; do
    #     echo "${PROJECT_ROOT%/}/${l}"
    # done > "${TAGS_FILE}.files"
    # fi
    eval $FILE_LIST_CMD > "${TAGS_FILE}.files"
    echo "$GSEARCH_EXE --file \"$TAGS_FILE.temp\" $GSEARCH_ARGS \"$PROJECT_ROOT\"" ${TAGS_FILE}.files
    # $GSEARCH_EXE -v --file "$TAGS_FILE.temp" --include="text" --lang-map="${LAND_MAP}" $GSEARCH_ARGS --files0-from="${TAGS_FILE}.files"
    $GSEARCH_EXE --file "$TAGS_FILE.temp" --include="text" --lang-map="${LAND_MAP}" $GSEARCH_ARGS --files0-from="${TAGS_FILE}.files"
else
    echo "$GSEARCH_EXE --file \"$TAGS_FILE.temp\" $GSEARCH_ARGS \"$PROJECT_ROOT\""
    $GSEARCH_EXE --file "$TAGS_FILE.temp" --include="text" --lang-map="${LAND_MAP}" $GSEARCH_ARGS
fi

if [ "$POST_PROCESS_CMD" != "" ]; then
    echo "Running post process"
    echo "$POST_PROCESS_CMD \"$TAGS_FILE.temp\""
    $POST_PROCESS_CMD "$TAGS_FILE.temp"
fi

echo "Replacing ID file"
echo "mv -f \"$TAGS_FILE.temp\" \"$TAGS_FILE\""
mv -f "$TAGS_FILE.temp" "$TAGS_FILE"

echo "Unlocking ID file..."
rm -f "$TAGS_FILE.lock"

echo "Done."

if [ $PAUSE_BEFORE_EXIT -eq 1 ]; then
    printf "Press ENTER to exit..."
    read -r
fi
