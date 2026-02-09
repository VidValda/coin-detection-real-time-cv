#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! source "${SCRIPT_DIR}/docker-lib.sh"; then
    echo "Error: Failed to load docker-lib.sh"
    echo "Make sure docker-lib.sh exists in the same directory as this script."
    exit 1
fi

DATA_DIR="${SCRIPT_DIR}/data"
IMAGE="${1:-coin-counter:latest}"
CMD="${2:-train_acquisition}"
USE_CAMERA="${USE_CAMERA:-true}"
CAMERA_DEV="${CAMERA_DEV:-/dev/video2}"

if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Error: Docker image '$IMAGE' not found."
    echo "Build it first with: ./docker-build.sh"
    exit 1
fi

setup_platform

if [ ! -d "$DATA_DIR" ]; then
    echo "Warning: Data directory not found at $DATA_DIR"
    echo "Creating data directory..."
    mkdir -p "$DATA_DIR"
fi

case "$PLATFORM" in
    linux)
        setup_camera_linux || exit 1
        ;;
    macos)
        echo "ℹ️  Note: Training on macOS is possible but camera support is limited."
        setup_camera_macos || exit 1
        ;;
    wsl2)
        echo "ℹ️  Note: Training on WSL2 is possible but camera support is limited."
        setup_camera_wsl2 || exit 1
        ;;
    windows)
        echo "ℹ️  Note: Training on Windows is possible but camera support is not available."
        setup_camera_windows
        ;;
    *)
        echo "⚠️  Unknown platform, attempting camera setup..."
        setup_camera_linux || exit 1
        ;;
esac

echo "========================================"
echo "WARNING: Training Mode"
echo "========================================"
echo "This will run with READ-WRITE access to:"
echo "  $DATA_DIR"
echo ""
echo "Training data and models will be saved"
echo "to this directory on your host system."
echo "========================================"
echo ""
echo "Platform: $(get_platform_display_name)"
echo "Image:    $IMAGE"
echo "Command:  $CMD"
if [ "$USE_CAMERA" = "true" ]; then
    echo "Camera:   $CAMERA_DEV"
else
    echo "Camera:   Disabled (using existing data)"
fi
echo "Data:     $DATA_DIR (read-write)"
echo ""
get_platform_features
echo ""
echo "Press Ctrl+C to stop"
echo "========================================"
echo ""

docker run -it --rm \
  --name coin_counter_train \
  $DISPLAY_ENV \
  $DISPLAY_VOLUME \
  -v "$DATA_DIR:/app/data:rw" \
  $DEVICE_FLAG \
  $NETWORK_FLAG \
  "$IMAGE" \
  "$CMD"

cleanup_display

echo ""
echo "Training session completed."
echo "Check $DATA_DIR for saved files."
