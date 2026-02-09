#!/usr/bin/env bash
#
# Usage:
#   Video mode (default):  ./docker-run.sh
#   Camera mode:           USE_CAMERA=true ./docker-run.sh
#   Custom camera:         USE_CAMERA=true CAMERA_DEV=/dev/video0 ./docker-run.sh
#   Training with camera:  USE_CAMERA=true ./docker-run.sh coin-counter train_acquisition
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
IMAGE="${1:-coin-counter:latest}"
CMD="${2:-coin_counter}"
USE_CAMERA="${USE_CAMERA:-false}"
CAMERA_DEV="${CAMERA_DEV:-/dev/video2}"

if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Error: Docker image '$IMAGE' not found."
    echo "Build it first with: ./docker-build.sh"
    exit 1
fi

if [ ! -d "$DATA_DIR" ]; then
    echo "Warning: Data directory not found at $DATA_DIR"
    echo "The container may not function correctly without model files."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Only check for camera if camera mode is enabled
if [ "$USE_CAMERA" = "true" ]; then
    if [ ! -e "$CAMERA_DEV" ]; then
        echo "Warning: Camera device $CAMERA_DEV not found."
        echo "Camera mode is enabled but device is unavailable."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    DEVICE_FLAG="--device=$CAMERA_DEV:$CAMERA_DEV"
else
    DEVICE_FLAG=""
fi

xhost +local:docker 2>/dev/null || true

echo "========================================"
echo "Running Coin Counter"
echo "========================================"
echo "Image:   $IMAGE"
echo "Command: $CMD"
if [ "$USE_CAMERA" = "true" ]; then
    echo "Mode:    Camera ($CAMERA_DEV)"
else
    echo "Mode:    Video (using test video from data/videos/)"
fi
echo "Data:    $DATA_DIR (read-only)"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================"
echo ""

docker run -it --rm \
  --name coin_counter \
  -e DISPLAY="$DISPLAY" \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$DATA_DIR:/app/data:ro" \
  $DEVICE_FLAG \
  --network host \
  "$IMAGE" \
  "$CMD"

xhost -local:docker 2>/dev/null || true

echo ""
echo "Container stopped."
