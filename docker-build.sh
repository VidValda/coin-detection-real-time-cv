#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "Building Coin Counter Docker Image"
echo "========================================"
echo ""
echo "Building with LibTorch support..."
echo "This will download ~200MB LibTorch archive"
echo "and may take 10-15 minutes."
echo ""

docker build \
  -t coin-counter:latest \
  .

echo ""
echo "✓ Build complete!"
echo ""
echo "========================================"
echo "Image created:"
echo "========================================"
docker images coin-counter:latest --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
echo ""
echo "Expected size: ~1.5GB (OpenCV + LibTorch + CNN/ResNet)"
echo ""
echo "Quick start:"
echo "  Run:   ./docker-run.sh coin-counter"
echo "  Train: ./docker-train.sh coin-counter train_acquisition"
echo ""
echo "Or use the convenience script:"
echo "  ./docker-build-and-run.sh"
echo ""
