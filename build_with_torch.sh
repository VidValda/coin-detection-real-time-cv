#!/usr/bin/env bash

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
LIBTORCH_ZIP="${BUILD_DIR}/libtorch.zip"
LIBTORCH_DIR="${BUILD_DIR}/libtorch"

if [[ -n "$1" ]]; then
  if [[ ! -d "$1" ]]; then
    echo "Error: directory does not exist: $1"
    exit 1
  fi
  LIBTORCH_DIR="$(cd "$1" && pwd)"
  echo "Using LibTorch at: ${LIBTORCH_DIR}"
else
  if [[ ! -d "${LIBTORCH_DIR}/share/cmake/Torch" ]]; then
    echo "Extracting LibTorch from ${LIBTORCH_ZIP}..."
    mkdir -p "${BUILD_DIR}"
    if [[ ! -f "${LIBTORCH_ZIP}" ]]; then
      echo "Error: ${LIBTORCH_ZIP} not found. Place libtorch-2.5.1.zip in project root and ensure Dockerfile copies it to /build/build/libtorch.zip, or run this script with path to existing LibTorch."
      exit 1
    fi
    if ! unzip -t "${LIBTORCH_ZIP}" > /dev/null 2>&1; then
      echo "Error: ${LIBTORCH_ZIP} is corrupted (zip test failed)"
      exit 1
    fi
    if ! unzip -q -o "${LIBTORCH_ZIP}" -d "${BUILD_DIR}"; then
      echo "Error: Failed to extract LibTorch"
      exit 1
    fi
    rm -f "${LIBTORCH_ZIP}"
    if [[ ! -d "${LIBTORCH_DIR}/share/cmake/Torch" ]] && [[ ! -d "${BUILD_DIR}/libtorch/share/cmake/Torch" ]]; then
      echo "Error: Unexpected zip layout. Expected libtorch/share/cmake/Torch inside archive."
      exit 1
    fi
    echo "LibTorch ready at ${LIBTORCH_DIR}"
  else
    echo "Using existing LibTorch at ${LIBTORCH_DIR}"
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
