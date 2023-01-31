# process-gopro-video
Combine and process GoPro videos so they can be uploaded to YouTube.

## Overview
This script will combine multiple video files from a GoPro camera
into one video file that can then be uploaded to YouTube and other
locations.

GoPro breaks long-format videos into [individual files based on the
camera model and video encoding format](https://community.gopro.com/s/article/GoPro-Camera-File-Naming-Convention?language=en_US).

This script will combine these files together using ffmpeg.

This scripts allows you to pass in one or more video IDs on the command
line, and it will find all videos for that video ID, or you can pass
in a custom input file via `-i` and it will be passed onto ffmpeg.

The custom input file should be in the format described [here](https://superuser.com/questions/1264399/can-ffmpeg-read-the-input-from-a-text-file#1264453).

## Execution
To execute this script, run the following commands once the
dependencies are installed:

```sh
# build ffmpeg input file from video IDs 10, 20, and 30
$ process.sh -d -s 2560:1440 -o output.mp4 10 20 30

# read ffmpeg input file from file instead of building via command line
$ process.sh -d -s 2560:1440 -i input.txt -o output.mp4
```

## Dependencies
- caffeinate - pre-installed with macOS
- cat - pre-installed with macOS and most Linux distributions
- ffmpeg - install using [Homebrew](https://formulae.brew.sh/formula/ffmpeg), another package manager or [manually](https://ffmpeg.org/).
- mktemp - pre-installed with macOS
- realpath - install via coreutils using [Homebrew](https://formulae.brew.sh/formula/coreutils), another package manager or [manually](https://www.gnu.org/software/coreutils/).

## Platform Support
This script was tested on macOS Monterey (12.6) using GNU Bash 5.2.15,
but should work on any GNU/Linux system that supports the dependencies
above.