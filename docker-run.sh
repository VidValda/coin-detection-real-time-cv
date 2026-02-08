#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
IMAGE="${1:-coin-counter:latest}"
CMD="${2:-coin_counter}"
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

if [ ! -e "$CAMERA_DEV" ]; then
    echo "Warning: Camera device $CAMERA_DEV not found."
    echo "The application may fail to open the camera."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

xhost +local:docker 2>/dev/null || true

echo "========================================"
echo "Running Coin Counter"
echo "========================================"
echo "Image:   $IMAGE"
echo "Command: $CMD"
echo "Camera:  $CAMERA_DEV"
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
  --device="$CAMERA_DEV:$CAMERA_DEV" \
  --network host \
  "$IMAGE" \
  "$CMD"

xhost -local:docker 2>/dev/null || true

echo ""
echo "Container stopped."
