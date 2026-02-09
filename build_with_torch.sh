#!/usr/bin/env bash

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
LIBTORCH_VERSION="${LIBTORCH_VERSION:-2.5.1}"
LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-${LIBTORCH_VERSION}%2Bcpu.zip"
LIBTORCH_ZIP="${BUILD_DIR}/libtorch.zip"
LIBTORCH_DIR="${BUILD_DIR}/libtorch"

download_libtorch() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1
    local min_size=$((190 * 1024 * 1024)) 

    while [ $attempt -le $max_attempts ]; do
        echo "Download attempt $attempt/$max_attempts..."

        if command -v wget &>/dev/null; then
            if wget --timeout=30 --tries=3 -q --show-progress -O "${output}" "${url}"; then
                download_success=true
            else
                download_success=false
            fi
        elif command -v curl &>/dev/null; then
            if curl --max-time 300 --retry 2 -# -L -o "${output}" "${url}"; then
                download_success=true
            else
                download_success=false
            fi
        else
            echo "Error: need wget or curl to download LibTorch."
            exit 1
        fi

        if $download_success && [[ -f "${output}" ]]; then
            local file_size=$(stat -f%z "${output}" 2>/dev/null || stat -c%s "${output}" 2>/dev/null || echo 0)
            if [ "$file_size" -ge "$min_size" ]; then
                echo "✓ Download successful (${file_size} bytes)"
                return 0
            else
                echo "⚠️  Downloaded file too small: ${file_size} bytes (expected >190MB)"
                rm -f "${output}"
            fi
        else
            echo "⚠️  Download command failed"
        fi

        if [ $attempt -lt $max_attempts ]; then
            local wait_time=$((attempt * 5))
            echo "Retrying in ${wait_time} seconds..."
            sleep $wait_time
        fi

        attempt=$((attempt + 1))
    done

    echo "❌ ERROR: Failed to download LibTorch after $max_attempts attempts"
    echo ""
    echo "This is common on Windows Docker Desktop due to network/DNS issues."
    echo ""
    echo "Workarounds:"
    echo "  1. Pre-download LibTorch manually:"
    echo "     Download from: https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-${LIBTORCH_VERSION}%2Bcpu.zip"
    echo "     Place in: ${BUILD_DIR}/"
    echo "     Then rebuild: docker build -t coin-counter:latest ."
    echo ""
    echo "  2. Configure Docker Desktop DNS:"
    echo "     Settings → Resources → Network → DNS Server → 8.8.8.8"
    echo ""
    echo "  3. Use host network (Windows WSL2 only):"
    echo "     docker build --network=host -t coin-counter:latest ."
    echo ""
    return 1
}

if [[ -n "$1" ]]; then
  if [[ ! -d "$1" ]]; then
    echo "Error: directory does not exist: $1"
    exit 1
  fi
  LIBTORCH_DIR="$(cd "$1" && pwd)"
  echo "Using LibTorch at: ${LIBTORCH_DIR}"
else
  if [[ -f "${LIBTORCH_DIR}/share/cmake/Torch/TorchConfigVersion.cmake" ]]; then
    if grep -q 'PACKAGE_VERSION "1\.' "${LIBTORCH_DIR}/share/cmake/Torch/TorchConfigVersion.cmake" 2>/dev/null; then
      echo "Removing old LibTorch 1.x (cannot load models from recent PyTorch)."
      rm -rf "${LIBTORCH_DIR}"
    fi
  fi
  if [[ ! -d "${LIBTORCH_DIR}/share/cmake/Torch" ]]; then
    # Check if already extracted in /build (from Dockerfile pre-download)
    if [[ -d "/build/build/libtorch/share/cmake/Torch" ]]; then
        echo "✓ Using pre-extracted LibTorch from /build/build/libtorch"
        LIBTORCH_DIR="/build/build/libtorch"
    else
        echo "LibTorch not found at ${LIBTORCH_DIR}. Downloading LibTorch ${LIBTORCH_VERSION} (CPU, ~200MB)..."
        mkdir -p "${BUILD_DIR}"

        if ! download_libtorch "${LIBTORCH_URL}" "${LIBTORCH_ZIP}"; then
          exit 1
        fi

    echo "Validating downloaded archive..."
    if ! unzip -t "${LIBTORCH_ZIP}" > /dev/null 2>&1; then
      echo "❌ ERROR: Downloaded file is corrupted (zip test failed)"
      echo "Removing corrupt file: ${LIBTORCH_ZIP}"
      rm -f "${LIBTORCH_ZIP}"
      exit 1
    fi

    echo "Extracting..."
    if ! unzip -q -o "${LIBTORCH_ZIP}" -d "${BUILD_DIR}"; then
      echo "❌ ERROR: Failed to extract LibTorch"
      exit 1
    fi

    rm -f "${LIBTORCH_ZIP}"
    if [[ ! -d "${LIBTORCH_DIR}/share/cmake/Torch" ]]; then
      if [[ -d "${BUILD_DIR}/libtorch/share/cmake/Torch" ]]; then
        :
      else
        echo "❌ ERROR: Unexpected zip layout. Check ${BUILD_DIR} and set CMAKE_PREFIX_PATH to the dir that contains share/cmake/Torch."
        exit 1
      fi
    fi
    echo "✓ LibTorch ready at ${LIBTORCH_DIR}"
    fi  # Close inner if from line 95
  else
    echo "✓ Using existing LibTorch at ${LIBTORCH_DIR}"
  fi
fi

LIBTORCH_CMAKE="${LIBTORCH_DIR}"
if [[ "${LIBTORCH_DIR}" = *" "* ]]; then
  LIBTORCH_LINK="${BUILD_DIR}/libtorch_link"
  rm -f "${LIBTORCH_LINK}"
  ln -s "${LIBTORCH_DIR}" "${LIBTORCH_LINK}"
  LIBTORCH_CMAKE="${LIBTORCH_LINK}"
  echo "Using symlink for CMake (path has spaces)"
fi

cd "${BUILD_DIR}"
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_TORCH=ON -DCMAKE_PREFIX_PATH="${LIBTORCH_CMAKE}"
make -j"$(nproc 2>/dev/null || echo 4)"
echo "Done. Run: ./coin_counter (keys 5/6 for CNN/ResNet18) or ./coin_counter_dl (DL-only, keys 1/2 for CNN/ResNet)"
