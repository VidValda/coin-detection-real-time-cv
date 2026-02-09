#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "data/videos/test1.zip" ]; then
  unzip -o -q data/videos/test1.zip -d data/videos/
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
