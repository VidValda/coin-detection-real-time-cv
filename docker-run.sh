#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! source "${SCRIPT_DIR}/docker-lib.sh"; then
    echo "Error: Failed to load docker-lib.sh"
    echo "Make sure docker-lib.sh exists in the same directory as this script."
    exit 1
fi

DATA_DIR="${SCRIPT_DIR}/data"
if [ ! -f "${SCRIPT_DIR}/data/videos/test1.mp4" ] && [ -f "${SCRIPT_DIR}/data/videos/video_part_aa" ]; then
  echo "Recombining video chunks to data/videos/test1.mp4..."
  cat "${SCRIPT_DIR}/data/videos/video_part_"* > "${SCRIPT_DIR}/data/videos/test1.mp4"
fi
IMAGE="${1:-coin-counter:latest}"
CMD="${2:-coin_counter}"
USE_CAMERA="${USE_CAMERA:-false}"
CAMERA_DEV="${CAMERA_DEV:-/dev/video2}"

if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Error: Docker image '$IMAGE' not found."
    echo "Build it first with: ./docker-build.sh"
    exit 1
fi

setup_platform

if [ ! -d "$DATA_DIR" ]; then
    echo "Warning: Data directory not found at $DATA_DIR"
    echo "The container may not function correctly without model files."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

case "$PLATFORM" in
    linux)
        setup_camera_linux || exit 1
        ;;
    macos)
        setup_camera_macos || exit 1
        ;;
    wsl2)
        setup_camera_wsl2 || exit 1
        ;;
    windows)
        setup_camera_windows
        ;;
    *)
        echo "⚠️  Unknown platform, attempting camera setup..."
        setup_camera_linux || exit 1
        ;;
esac

echo "========================================"
echo "Coin Counter - Inference Mode"
echo "========================================"
echo "Platform: $(get_platform_display_name)"
echo "Image:    $IMAGE"
echo "Command:  $CMD"
if [ "$USE_CAMERA" = "true" ]; then
    echo "Input:    Camera ($CAMERA_DEV)"
else
    echo "Input:    Video (data/videos/)"
fi
echo "Data:     $DATA_DIR (read-only)"
echo ""
get_platform_features
echo ""
echo "Press Ctrl+C to stop"
echo "========================================"
echo ""

docker run -it --rm \
  --name coin_counter \
  $DISPLAY_ENV \
  $DISPLAY_VOLUME \
  -v "$DATA_DIR:/app/data:ro" \
  $DEVICE_FLAG \
  $NETWORK_FLAG \
  "$IMAGE" \
  "$CMD"

cleanup_display

echo ""
echo "Container stopped."
