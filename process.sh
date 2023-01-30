#!/bin/bash

# process.sh -d -s 2560:1440 -o output.mp4 group1 group2 ...

#
#  nullglob - If set, Bash allows filename patterns which
#             match no files to expand to a null string,
#             rather than themselves.
#
shopt -s nullglob

usage() {
    cat << EOT 1>&2
Usage: process.sh [-h] [-d] [-f] [-p pfx] [-t type] -s w:h -o fn group ...

-d           output debug information
-f           overwrite output file if it already exists
-h           show help
-o fn        output combined file to fn
-p pfx       use pfx as prefix for file names (default: GX)
-s w:h       scale video to w width and h height pixels
-t type      use type as extension for file names (default: MP4)

group ...    name of one or more groups to look for

EOT

    exit
}

[[ $# -eq 0 ]] && usage

debug() {
    if [[ ${DEBUG} == 'true' ]]; then
        echo $*
    fi
}

while getopts ":hdfo:p:s:t:" FLAG; do
    case "${FLAG}" in
        d)
            DEBUG=true

            debug "Debug mode turned on."
            ;;

        f)
            FORCE_OVERWRITE=true

            debug "Force overwrite mode turned on."
            ;;

        o)
            OUTPUT_FILE=${OPTARG}

            debug "Output file set to '${OUTPUT_FILE}'."
            ;;

        p)
            FILE_PREFIX=${OPTARG}

            debug "File prefix set to '${FILE_PREFIX}'."
            ;;

        s)
            SCALING=${OPTARG}

            if [[ ${SCALING} =~ [0-9]+:[0-9]+ ]]; then
                debug "Scaling set to '${SCALING}'."
            else
                debug "Invalid scaling: '${SCALING}'."

                usage
            fi
            ;;

        t)
            FILE_TYPE=${OPTARG}

            debug "File type set to '${FILE_TYPE}'."
            ;;

        h | *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

if [[ -z ${SCALING} ]] || [[ -z ${OUTPUT_FILE} ]]; then
    debug "Missing scaling and/or output file name."

    usage
fi

setDefaults() {
    if [[ -z ${FILE_PREFIX} ]]; then
        FILE_PREFIX='GX'
    fi

    if [[ -z ${FILE_TYPE} ]]; then
        FILE_TYPE='MP4'
    fi
}

setDefaults

dependencyCheck() {
    for d in caffeinate cat ffmpeg mktemp realpath; do
        debug "Checking for dependency '$d'."

        if ! command -v $d &> /dev/null; then
            echo "Dependency '$d' is missing."

            exit
        fi
    done
}

dependencyCheck

cleanup() {
    debug "Deleting temp file '${INPUT_FILE}'."

    rm "${INPUT_FILE}"
}

waitForUpload() {
    echo "Please upload the video to YouTube and then type CTRL+C once it has completed."

    caffeinate
}

INPUT_FILE=$(mktemp)
GOPRO_GROUP_FORMAT='%04d'

# for each group listed on command line
for GROUP_ID in $*; do
    GROUP=$(printf "${GOPRO_GROUP_FORMAT}" ${GROUP_ID})

    debug "Checking group '${GROUP}'."

    # if any files exist for said group
    for GOPRO_FILE in ${FILE_PREFIX}??${GROUP}.${FILE_TYPE}; do
        FULL_PATH=$(realpath ${GOPRO_FILE})

        debug "Adding file '${FULL_PATH}' to '${INPUT_FILE}'."

        echo "file '${FULL_PATH}'" >> "${INPUT_FILE}"
    done
done

if [[ ! -s ${INPUT_FILE} ]]; then
    echo "No files to process. Exiting."

    cleanup

    exit
fi

if [[ ${DEBUG} == 'true' ]]; then
    debug "=== Contents of '${INPUT_FILE}' ==="

    cat "${INPUT_FILE}"

    debug "=== End contents of '${INPUT_FILE}' ==="
fi

debug "Running FFmpeg (in: ${INPUT_FILE}, out: ${OUTPUT_FILE}, scaling: ${SCALING})."

caffeinate ffmpeg \
  -hide_banner \
  -c copy \
  -f concat \
  -safe 0 \
  -i "${INPUT_FILE}" \
  -vf scale=${SCALING} \
  ${OUTPUT_FILE}

cleanup

echo "The videos have been combined into '${OUTPUT_FILE}'."

waitForUpload
