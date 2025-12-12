#!/bin/bash
#
# convert_tvd.sh - Convert Telemed TVD files to video formats using EchoWave from WSL
#
# Usage: ./convert_tvd.sh [directory_path] [format]
#
# Arguments:
#   directory_path - Path to directory containing TVD files (default: current directory)
#   format        - Output format: mp4, avi_comp, avi, avi_wmv9, dcm_jpeg_cine, dcm_cine (default: mp4)
#
# Examples:
#   ./convert_tvd.sh                                    # Convert TVDs in current dir to MP4
#   ./convert_tvd.sh /mnt/c/recordings                  # Convert TVDs in specified dir to MP4
#   ./convert_tvd.sh /mnt/c/recordings avi_comp         # Convert to AVI compressed
#
# Requirements:
#   - EchoWave II must be installed at: C:\Program Files\Telemed\Echo Wave II Application\EchoWave II
#   - EchoWave II should be running (start it first)
#   - This script must be run from WSL on Windows
#

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Path to EchoWave (confirmed location)
ECHOWAVE="/mnt/c/Program Files/Telemed/Echo Wave II Application/EchoWave II/EchoWave.exe"

# Check if EchoWave exists
if [ ! -f "$ECHOWAVE" ]; then
    echo -e "${RED}ERROR: EchoWave.exe not found at: $ECHOWAVE${NC}"
    echo "Please verify EchoWave II is installed."
    exit 1
fi

echo -e "${GREEN}✓ Found EchoWave${NC}"

# Parse arguments
LINUX_PATH="${1:-.}"  # Default to current directory if not specified
OUTPUT_FORMAT="${2:-mp4}"  # Default to mp4 if not specified

# Validate output format
VALID_FORMATS=("mp4" "avi_comp" "avi" "avi_cust" "avi_wmv9" "dcm_jpeg_cine" "dcm_cine")
if [[ ! " ${VALID_FORMATS[@]} " =~ " ${OUTPUT_FORMAT} " ]]; then
    echo -e "${RED}ERROR: Invalid output format '${OUTPUT_FORMAT}'${NC}"
    echo "Valid formats: ${VALID_FORMATS[*]}"
    exit 1
fi

# Check if directory exists
if [ ! -d "$LINUX_PATH" ]; then
    echo -e "${RED}ERROR: Directory not found: $LINUX_PATH${NC}"
    exit 1
fi

# Convert to absolute path if relative
LINUX_PATH=$(cd "$LINUX_PATH" && pwd)

# Check if directory contains TVD files
TVD_COUNT=$(find "$LINUX_PATH" -maxdepth 1 -name "*.tvd" -type f | wc -l)
if [ "$TVD_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}WARNING: No .tvd files found in: $LINUX_PATH${NC}"
    echo "Nothing to convert."
    exit 0
fi

echo -e "${BLUE}Found $TVD_COUNT TVD file(s) to convert${NC}"

# Convert WSL path to Windows path
WINDOWS_PATH=$(wslpath -w "$LINUX_PATH")

if [ -z "$WINDOWS_PATH" ]; then
    echo -e "${RED}ERROR: Failed to convert path to Windows format${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Linux path:${NC}   $LINUX_PATH"
echo -e "${GREEN}✓ Windows path:${NC} $WINDOWS_PATH"
echo -e "${GREEN}✓ Output format:${NC} $OUTPUT_FORMAT"
echo ""

# Check if EchoWave is running
if ! tasklist.exe 2>/dev/null | grep -qi "EchoWave.exe"; then
    echo -e "${YELLOW}WARNING: EchoWave.exe is not running!${NC}"
    echo "Please start EchoWave II before running this script."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Show warning about conversion time
echo -e "${YELLOW}⚠ WARNING: Video conversion is VERY SLOW${NC}"
echo "  - Expect 5-10 minutes per file depending on length"
echo "  - No progress bar will be shown"
echo "  - Do not close this terminal while converting"
echo ""

# Confirm before proceeding
read -p "Start conversion? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Run EchoWave conversion
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting conversion...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Record start time
START_TIME=$(date +%s)

# Run the conversion command via PowerShell (better handling of paths with spaces from WSL)
powershell.exe -Command "& 'C:\Program Files\Telemed\Echo Wave II Application\EchoWave II\EchoWave.exe' -convert_directory '$WINDOWS_PATH' tvd $OUTPUT_FORMAT"
EXIT_CODE=$?

# Record end time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${BLUE}========================================${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Conversion completed successfully!${NC}"
else
    echo -e "${RED}✗ Conversion failed with exit code: $EXIT_CODE${NC}"
fi
echo -e "${BLUE}========================================${NC}"
echo "Time elapsed: ${MINUTES}m ${SECONDS}s"
echo ""

# List created files
VIDEO_EXT="${OUTPUT_FORMAT//_comp/}"  # Remove _comp suffix
VIDEO_EXT="${VIDEO_EXT//_cust/}"      # Remove _cust suffix
VIDEO_EXT="${VIDEO_EXT//_wmv9/}"      # Remove _wmv9 suffix
VIDEO_EXT="${VIDEO_EXT//dcm_jpeg_cine/dcm}"  # DICOM format
VIDEO_EXT="${VIDEO_EXT//dcm_cine/dcm}"

echo -e "${GREEN}Created files:${NC}"
find "$LINUX_PATH" -maxdepth 1 -name "*.${VIDEO_EXT}" -type f -printf "  - %f\n" 2>/dev/null | head -20

if [ $(find "$LINUX_PATH" -maxdepth 1 -name "*.${VIDEO_EXT}" -type f 2>/dev/null | wc -l) -gt 20 ]; then
    echo "  ... and more"
fi

echo ""
echo -e "${BLUE}Output directory:${NC} $LINUX_PATH"

exit $EXIT_CODE
