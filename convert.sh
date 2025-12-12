#!/bin/bash

# Converting raw mp4 to re-encoded mp4
# - 2025-11-16 jkang first created
#   - Note: current mp4 is 117.041 fps, which is not standard
#   - It also includes 7 frames with different fps, so needs to fix fps.
#   - For now, set it to integer 118 fps for convenience 

if [ $# -eq 0 ]; then
  echo "Usage: $0 <input.mp4>"
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE%.*}_h264.mp4"

ffmpeg -i "$INPUT_FILE" \
  -r 60 \
  -c:v libx264 -crf 23 -preset slow -profile:v main -pix_fmt yuv420p \
  "$OUTPUT_FILE"

echo "Conversion complete: $OUTPUT_FILE"


