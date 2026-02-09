#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "data/videos/test1.mp4" ] && [ -f "data/videos/video_part_aa" ]; then
  echo "Recombining video chunks to data/videos/test1.mp4..."
  cat data/videos/video_part_* > data/videos/test1.mp4
fi

echo "========================================"
echo "Build and Run Coin Counter"
echo "========================================"
echo ""

echo "Step 1: Building Docker image..."
echo ""
./docker-build.sh

echo ""
echo "========================================"
echo "Step 2: Starting coin counter..."
echo "========================================"
echo ""
sleep 2

./docker-run.sh coin-counter
