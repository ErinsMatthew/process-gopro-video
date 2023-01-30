#!/bin/bash

# process.sh -d -s 2560:1440 -o output.mp4 10 20 30

# https://community.gopro.com/s/article/GoPro-Camera-File-Naming-Convention?language=en_US

#
#  nullglob - If set, Bash allows filename patterns which
#             match no files to expand to a null string,
#             rather than themselves.
#
shopt -s nullglob

usage() {
    cat << EOT 1>&2
Usage: process.sh [-h] [-d] [-f] [-n] [-p pfx] [-t type] -s w:h -o fn video ...

-d           output debug information
-f           overwrite output file if it already exists
-h           show help
-n           don't wait for upload to YouTube
-o fn        output combined file to fn
-p pfx       use pfx as prefix for file names (default: GX)
-s w:h       scale video to w width and h height pixels
-t type      use type as extension for file names (default: MP4)

video ...    number of one or more videos to look for

EOT

    exit
}

[[ $# -eq 0 ]] && usage

debug() {
    if [[ ${DEBUG} == 'true' ]]; then
        echo $*
    fi
}

while getopts ":hdfno:p:s:t:" FLAG; do
    case "${FLAG}" in
        d)
            DEBUG='true'

            debug "Debug mode turned on."
            ;;

        f)
            OVERWRITE_OPTION='-y'

            debug "Force overwrite mode turned on."
            ;;
        
        n)
            NO_WAIT=true

            debug "No YouTube wait mode turned on."
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

shift $(( OPTIND - 1 ))

if [[ -z ${SCALING} ]] || [[ -z ${OUTPUT_FILE} ]]; then
    debug "Missing scaling and/or output file name."

    usage
fi

setDefaults() {
    if [[ -z ${OVERWRITE_OPTION} ]]; then
        OVERWRITE_OPTION='-n'

        debug "Overwrite option set to default of '${OVERWRITE_OPTION}'."
    fi

    if [[ -z ${FILE_PREFIX} ]]; then
        FILE_PREFIX='GX'

        debug "File prefix set to default of '${FILE_PREFIX}'"
    fi

    if [[ -z ${FILE_TYPE} ]]; then
        FILE_TYPE='MP4'

        debug "File type set to default of '${FILE_TYPE}'."
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

buildInputFile() {
    INPUT_FILE=$(mktemp)

    debug "Building input file '${INPUT_FILE}'."

    GOPRO_VIDEO_ID_FORMAT='%04d'

    # for each video ID listed on command line
    for VIDEO_ID in $*; do
        # format it as a four-digit number
        FORMATTED_VIDEO_ID=$(printf "${GOPRO_VIDEO_ID_FORMAT}" ${VIDEO_ID})

        debug "Checking video ID '${FORMATTED_VIDEO_ID}'."

        # if any files exist for formatted video ID
        for GOPRO_FILE in ${FILE_PREFIX}??${FORMATTED_VIDEO_ID}.${FILE_TYPE}; do
            FULL_FILE_NAME=$(realpath ${GOPRO_FILE})

            debug "Adding file '${FULL_FILE_NAME}' to '${INPUT_FILE}'."

            echo "file '${FULL_FILE_NAME}'" >> "${INPUT_FILE}"
        done
    done

    if [[ ${DEBUG} == 'true' && -s ${INPUT_FILE} ]]; then
        debug "=== Contents of '${INPUT_FILE}' ==="

        cat "${INPUT_FILE}"

        debug "=== End contents of '${INPUT_FILE}' ==="
    fi
}

combineVideo() {
    debug "Combining video into '${OUTPUT_FILE}'."

    debug << EOT
Running FFmpeg (in: ${INPUT_FILE}, out: ${OUTPUT_FILE},
  scaling: ${SCALING}, overwrite: ${OVERWRITE_OPTION}).
EOT

    caffeinate ffmpeg \
      -hide_banner \
      -c copy \
      -f concat \
      -safe 0 \
      -i "${INPUT_FILE}" \
      -vf scale=${SCALING} \
      ${OVERWRITE_OPTION} \
      ${OUTPUT_FILE}

    cleanup

    echo "The videos have been combined into '${OUTPUT_FILE}'."
}

waitForUpload() {
    if [[ $NO_WAIT != 'true' ]]; then
        echo "Please upload the video to YouTube and then type CTRL+C once it has completed."

        caffeinate
    fi
}

buildInputFile

if [[ ! -s ${INPUT_FILE} ]]; then
    echo "No files to process. Exiting."

    cleanup

    exit
fi

combineVideo

waitForUpload
