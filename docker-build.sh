#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "Building Coin Counter Docker Images"
echo "========================================"
echo ""

echo "Building lightweight SVM-only image..."
echo "This should take 3-5 minutes depending on your system."
echo ""
docker build \
  --build-arg BUILD_WITH_TORCH=OFF \
  -t coin-counter:svm \
  -t coin-counter:latest \
  .

echo ""
echo "✓ SVM variant built successfully"
echo ""
echo "========================================"
echo ""

echo "Building full image with LibTorch..."
echo "WARNING: This will download ~200MB LibTorch archive and may take 10-15 minutes."
echo ""
docker build \
  --build-arg BUILD_WITH_TORCH=ON \
  -t coin-counter:dl \
  .

echo ""
echo "✓ DL variant built successfully"
echo ""
echo "========================================"
echo "Build complete!"
echo "========================================"
echo ""
echo "Images created:"
docker images coin-counter --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
echo ""
echo "Expected sizes:"
echo "  - coin-counter:svm   ~500MB  (OpenCV + SVM models)"
echo "  - coin-counter:dl    ~1.5GB  (includes LibTorch + CNN/ResNet)"
echo ""
echo "Quick start:"
echo "  Run SVM:  ./docker-run.sh coin-counter:svm"
echo "  Run DL:   ./docker-run.sh coin-counter:dl"
echo "  Train:    ./docker-train.sh coin-counter:svm train_acquisition"
echo ""
