#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
IMAGE="${1:-coin-counter:svm}"
CMD="${2:-train_acquisition}"
CAMERA_DEV="${CAMERA_DEV:-/dev/video2}"

if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Error: Docker image '$IMAGE' not found."
    echo "Build it first with: ./docker-build.sh"
    exit 1
fi

if [ ! -d "$DATA_DIR" ]; then
    echo "Warning: Data directory not found at $DATA_DIR"
    echo "Creating data directory..."
    mkdir -p "$DATA_DIR"
fi

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

xhost +local:docker 2>/dev/null || true

echo "Image:   $IMAGE"
echo "Command: $CMD"
echo "Camera:  $CAMERA_DEV"
echo "Data:    $DATA_DIR (read-write)"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================"
echo ""

docker run -it --rm \
  --name coin_counter_train \
  -e DISPLAY="$DISPLAY" \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$DATA_DIR:/app/data:rw" \
  --device="$CAMERA_DEV:$CAMERA_DEV" \
  --network host \
  "$IMAGE" \
  "$CMD"

xhost -local:docker 2>/dev/null || true

echo ""
echo "Training session completed."
echo "Check $DATA_DIR for saved files."
