#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIBTORCH_VERSION="${LIBTORCH_VERSION:-2.5.1}"
LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-${LIBTORCH_VERSION}%2Bcpu.zip"
LIBTORCH_ZIP="${PROJECT_DIR}/libtorch-${LIBTORCH_VERSION}.zip"
MIN_SIZE=$((190 * 1024 * 1024))

echo "========================================"
echo "LibTorch Pre-Download"
echo "========================================"
echo "Version: ${LIBTORCH_VERSION}"
echo "Target:  ${LIBTORCH_ZIP}"
echo ""

if [[ -f "${LIBTORCH_ZIP}" ]]; then
    FILE_SIZE=$(stat -f%z "${LIBTORCH_ZIP}" 2>/dev/null || stat -c%s "${LIBTORCH_ZIP}" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -ge "$MIN_SIZE" ]; then
        echo "✓ LibTorch already downloaded (${FILE_SIZE} bytes)"
        echo ""
        exit 0
    else
        echo "⚠️  Existing file is too small (${FILE_SIZE} bytes), re-downloading..."
        rm -f "${LIBTORCH_ZIP}"
    fi
fi

echo "Downloading LibTorch (~200MB)..."
echo "This downloads on your machine (not in Docker),"
echo "which avoids Docker Desktop network issues."
echo ""

if command -v wget &>/dev/null; then
    wget --show-progress -O "${LIBTORCH_ZIP}" "${LIBTORCH_URL}" || {
        echo "❌ Download failed"
        rm -f "${LIBTORCH_ZIP}"
        exit 1
    }
elif command -v curl &>/dev/null; then
    curl -# -L -o "${LIBTORCH_ZIP}" "${LIBTORCH_URL}" || {
        echo "❌ Download failed"
        rm -f "${LIBTORCH_ZIP}"
        exit 1
    }
else
    echo "❌ ERROR: Need wget or curl to download"
    echo ""
    echo "Manual download:"
    echo "  URL: ${LIBTORCH_URL}"
    echo "  Save to: ${LIBTORCH_ZIP}"
    exit 1
fi

FILE_SIZE=$(stat -f%z "${LIBTORCH_ZIP}" 2>/dev/null || stat -c%s "${LIBTORCH_ZIP}" 2>/dev/null || echo 0)
if [ "$FILE_SIZE" -lt "$MIN_SIZE" ]; then
    echo "❌ ERROR: Download incomplete (${FILE_SIZE} bytes, expected >190MB)"
    rm -f "${LIBTORCH_ZIP}"
    exit 1
fi

echo ""
echo "✓ Download successful (${FILE_SIZE} bytes)"
echo ""
echo "LibTorch is ready! Docker build will use this local copy."
echo ""
