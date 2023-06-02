#!/usr/bin/env bash

set -o nounset

# https://community.gopro.com/s/article/GoPro-Camera-File-Naming-Convention?language=en_US

#
#  nullglob - If set, Bash allows filename patterns which
#             match no files to expand to a null string,
#             rather than themselves.
#
shopt -s nullglob

usage() {
    cat << EOT 1>&2
Usage: process.sh [-h] [-d] [-f] [-n] [-p pfx] [-t type] -s w:h -o fn { -i fn | video ... }

OPTIONS
=======
-d           output debug information
-f           overwrite output file if it already exists
-h           show help
-n           don't wait for upload to YouTube
-i fn        input file to use when calling ffmpeg
-o fn        output combined file to fn
-p pfx       use pfx as prefix for file names (default: GX)
-s w:h       scale video to w width and h height pixels
-t type      use type as extension for file names (default: MP4)

ARGUMENTS
=========
video ...    number of one or more videos to look for

EXAMPLES
========
# build ffmpeg input file from video IDs 10, 20, and 30
$ process.sh -d -s 2560:1440 -o output.mp4 10 20 30

# read ffmpeg input file from file instead of building via command line
$ process.sh -d -s 2560:1440 -i input.txt -o output.mp4

EOT

    exit
}

initGlobals() {
    declare -gA GLOBALS=(
        [CUSTOM_INPUT_FILE]=''          # -i
        [DEBUG]='false'                 # -d
        [FILE_PREFIX]=''                # -p
        [FILE_TYPE]=''                  # -t
        [INPUT_FILE]=''                 # -i
        [NO_WAIT]='false'               # -n
        [OUTPUT_FILE]=''                # -o
        [OVERWRITE_OPTION]=''           # -f
        [SCALING]=''                    # -s

        [VIDEO_IDS]=''                  # video ...
    )
}

debug() {
    if [[ ${GLOBALS[DEBUG]} == 'true' ]]; then
        echo "$@"
    fi
}

processOptions() {
    [[ $# -eq 0 ]] && usage

    while getopts ":hdfni:o:p:s:t:" FLAG; do
        case "${FLAG}" in
            d)
                GLOBALS[DEBUG]='true'

                debug "Debug mode turned on."
                ;;

            f)
                GLOBALS[OVERWRITE_OPTION]='-y'

                debug "Force overwrite mode turned on."
                ;;

            i)
                GLOBALS[INPUT_FILE]=${OPTARG}

                debug "Input file set to '${GLOBALS[INPUT_FILE]}'."

                if [[ -s ${GLOBALS[INPUT_FILE]} ]]; then
                    GLOBALS[CUSTOM_INPUT_FILE]='true'

                    debug "Custom input file mode turned on."
                fi
                ;;

            n)
                GLOBALS[NO_WAIT]='true'

                debug "No wait mode turned on."
                ;;

            o)
                GLOBALS[OUTPUT_FILE]=${OPTARG}

                debug "Output file set to '${GLOBALS[OUTPUT_FILE]}'."
                ;;

            p)
                GLOBALS[FILE_PREFIX]=${OPTARG}

                debug "File prefix set to '${GLOBALS[FILE_PREFIX]}'."
                ;;

            s)
                GLOBALS[SCALING]=${OPTARG}

                if [[ ${GLOBALS[SCALING]} =~ [0-9]+:[0-9]+ ]]; then
                    debug "Scaling set to '${GLOBALS[SCALING]}'."
                else
                    debug "Invalid scaling: '${GLOBALS[SCALING]}'."

                    usage
                fi
                ;;

            t)
                GLOBALS[FILE_TYPE]=${OPTARG}

                debug "File type set to '${GLOBALS[FILE_TYPE]}'."
                ;;

            h | *)
                usage
                ;;
        esac
    done

    shift $(( OPTIND - 1 ))

    GLOBALS[VIDEO_IDS]=$*

    [[ $# -eq 0 ]] && usage
}

validateInputs() {
    if [[ -z ${GLOBALS[SCALING]} ]] || [[ -z ${GLOBALS[OUTPUT_FILE]} ]]; then
        debug "Missing scaling and/or output file name."

        usage
    fi
}

setDefaults() {
    if [[ -z ${GLOBALS[OVERWRITE_OPTION]} ]]; then
        GLOBALS[OVERWRITE_OPTION]='-n'

        debug "Overwrite option set to default of '${GLOBALS[OVERWRITE_OPTION]}'."
    fi

    if [[ -z ${GLOBALS[FILE_PREFIX]} ]]; then
        GLOBALS[FILE_PREFIX]='GX'

        debug "File prefix set to default of '${GLOBALS[FILE_PREFIX]}'"
    fi

    if [[ -z ${GLOBALS[FILE_TYPE]} ]]; then
        GLOBALS[FILE_TYPE]='MP4'

        debug "File type set to default of '${GLOBALS[FILE_TYPE]}'."
    fi
}

checkForDependency() {
    debug "Checking for dependency '$1'."

    if ! command -v "$1" &> /dev/null; then
        echo "Dependency '$1' is missing." > /dev/stderr

        exit
    fi
}

dependencyCheck() {
    local DEPENDENCY

    for DEPENDENCY in caffeinate cat ffmpeg mktemp realpath; do
        checkForDependency "${DEPENDENCY}"
    done
}

cleanup() {
    if [[ ${GLOBALS[CUSTOM_INPUT_FILE]} != 'true' ]]; then
        debug "Deleting temp file '${GLOBALS[INPUT_FILE]}'."

        rm "${GLOBALS[INPUT_FILE]}"
    fi
}

performSetup() {
    initGlobals

    processOptions "$@"

    validateInputs

    setDefaults

    dependencyCheck
}

buildInputFile() {
    local VIDEO_ID
    local FORMATTED_VIDEO_ID
    local GOPRO_FILE
    local FULL_FILE_NAME

    GLOBALS[INPUT_FILE]=$(mktemp)

    debug "Building input file '${GLOBALS[INPUT_FILE]}'."

    # for each video ID listed on command line
    for VIDEO_ID in ${GLOBALS[VIDEO_IDS]}; do
        # format it as a four-digit number
        printf -v FORMATTED_VIDEO_ID '%04d' "${VIDEO_ID}"

        debug "Checking video ID '${FORMATTED_VIDEO_ID}'."

        # if any files exist for formatted video ID
        for GOPRO_FILE in "${GLOBALS[FILE_PREFIX]}"??"${FORMATTED_VIDEO_ID}"."${GLOBALS[FILE_TYPE]}"; do
            FULL_FILE_NAME=$(realpath "${GOPRO_FILE}")

            debug "Adding file '${FULL_FILE_NAME}' to '${GLOBALS[INPUT_FILE]}'."

            echo "file '${FULL_FILE_NAME}'" >> "${GLOBALS[INPUT_FILE]}"
        done
    done
}

showInputFile() {
    if [[ ${GLOBALS[DEBUG]} == 'true' && -s ${GLOBALS[INPUT_FILE]} ]]; then
        debug "=== Contents of '${GLOBALS[INPUT_FILE]}' ==="

        cat "${GLOBALS[INPUT_FILE]}"

        debug "=== End contents of '${GLOBALS[INPUT_FILE]}' ==="
    fi
}

combineVideos() {
    if [[ ! -s ${GLOBALS[INPUT_FILE]} ]]; then
        echo "No files to process. Exiting." > /dev/stderr

        cleanup

        exit
    fi

    debug "Combining video into '${GLOBALS[OUTPUT_FILE]}'."

    debug << EOT
Running FFmpeg (in: ${GLOBALS[INPUT_FILE]}, out: ${GLOBALS[OUTPUT_FILE]},
  scaling: ${GLOBALS[SCALING]}, overwrite: ${GLOBALS[OVERWRITE_OPTION]}).
EOT

    # https://ffmpeg.org/ffmpeg.html
    # https://support.google.com/youtube/answer/6039860?hl=en

    caffeinate ffmpeg \
      -hide_banner \
      "${GLOBALS[OVERWRITE_OPTION]}" \
      -f concat \
      -safe 0 \
      -i "${GLOBALS[INPUT_FILE]}" \
      -c:a flac \
      -c:v h264 \
      -filter:v scale=hd1080 \
      "${GLOBALS[OUTPUT_FILE]}"

    cleanup

    echo "The videos have been combined into '${GLOBALS[OUTPUT_FILE]}'."
}

waitForUpload() {
    if [[ ${GLOBALS[NO_WAIT]} != 'true' ]]; then
        echo "Please upload the video to YouTube and then type CTRL+C once it has completed."

        caffeinate
    fi
}

performSetup "$@"

if [[ ${GLOBALS[CUSTOM_INPUT_FILE]} != 'true' ]]; then
    buildInputFile "$@"
fi

showInputFile

combineVideos

waitForUpload
