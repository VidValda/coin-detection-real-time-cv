#!/usr/bin/env bash


set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APPDIR="CoinCounter.AppDir"
IMAGE_NAME="coin-counter:latest"

echo "========================================"
echo "  Building Coin Counter AppImage"
echo "========================================"
echo ""

echo "Step 1: Building Docker image..."
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "Docker image not found. Building..."
    ./docker-build.sh
else
    echo "Using existing Docker image: $IMAGE_NAME"
    echo "To rebuild: docker rmi $IMAGE_NAME && ./docker-build.sh"
fi
echo ""

echo "Step 2: Extracting binaries from Docker..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR"/usr/{bin,lib,share/coin-counter}

docker rm -f coin_appimage_temp 2>/dev/null || true
docker create --name coin_appimage_temp "$IMAGE_NAME" sleep infinity > /dev/null
trap 'docker rm -f coin_appimage_temp 2>/dev/null || true' EXIT INT TERM
echo "  Extracting executables..."
docker cp coin_appimage_temp:/app/bin/coin_counter "$APPDIR/usr/bin/"
docker cp coin_appimage_temp:/app/bin/camera_calibration "$APPDIR/usr/bin/"
docker cp coin_appimage_temp:/app/bin/train_svm "$APPDIR/usr/bin/"
docker cp coin_appimage_temp:/app/bin/train_acquisition "$APPDIR/usr/bin/"

echo "  Extracting LibTorch libraries..."
docker cp coin_appimage_temp:/app/lib/. "$APPDIR/usr/lib/"

echo "  Extracting data files from Docker..."
docker cp coin_appimage_temp:/app/data/. "$APPDIR/usr/share/coin-counter/data/" 2>/dev/null || true

echo "  Copying data files from host (models, configs)..."
if [ -d "$PROJECT_ROOT/data" ]; then
    cp -r "$PROJECT_ROOT/data"/* "$APPDIR/usr/share/coin-counter/data/" 2>/dev/null || true
    echo "    ✓ Copied models and data files"
else
    echo "    ⚠ Warning: data/ directory not found on host"
fi
echo ""

echo "Step 3: Bundling dependencies from Docker container..."

# Start container so we can run ldd inside it
docker start coin_appimage_temp > /dev/null

# Collect all required library paths by running ldd on each binary (use /usr/bin/ldd in case PATH is minimal)
BINARIES="coin_counter camera_calibration train_svm train_acquisition"
LDDPATH_LIST=""
for bin in $BINARIES; do
    out=$(docker exec coin_appimage_temp /usr/bin/ldd /app/bin/$bin 2>/dev/null) || true
    LDDPATH_LIST="$LDDPATH_LIST $(echo "$out" | sed -n 's/.*=>[[:space:]]*\([^[:space:]]*\).*/\1/p' | grep '^/' || true)"
done

# Copy each library from the container, excluding system/GPU libs
should_skip() {
    local libname="$1"
    case "$libname" in
        libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|ld-linux*)
            return 0 ;;
        libgcc_s.so*|libstdc++.so*)
            return 0 ;;
        libX11.so*|libxcb.so*|libXext.so*|libXrender.so*|libXau.so*)
            return 0 ;;
        libGL.so*|libGLX.so*|libEGL.so*|libdrm.so*)
            return 0 ;;
        libnvidia*|libcuda*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

COPIED=0
for path in $LDDPATH_LIST; do
    [ -z "$path" ] && continue
    [[ "$path" != /* ]] && continue
    libname=$(basename "$path")
    should_skip "$libname" && continue
    [ -f "$APPDIR/usr/lib/$libname" ] && continue
    if docker cp "coin_appimage_temp:$path" "$APPDIR/usr/lib/$libname" 2>/dev/null; then
        COPIED=$((COPIED + 1))
        # Create SONAME symlink if loader expects a different name (readelf may be missing on host)
        soname=$(readelf -d "$APPDIR/usr/lib/$libname" 2>/dev/null | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p') || true
        if [ -n "$soname" ] && [ "$soname" != "$libname" ] && [ ! -e "$APPDIR/usr/lib/$soname" ]; then
            ln -sf "$libname" "$APPDIR/usr/lib/$soname"
        fi
    fi
done

# Fallback: if ldd gave no paths, copy known libs from container
if [ "$COPIED" -eq 0 ]; then
    echo "  ldd yielded no paths; copying known libs from container..."
fi
# Always ensure OpenCV and libaribb24 are present (required by coin_counter)
for lib_path in \
    /usr/lib/x86_64-linux-gnu/libaribb24.so.0 \
    /lib/x86_64-linux-gnu/libaribb24.so.0; do
    name=$(basename "$lib_path")
    if [ ! -f "$APPDIR/usr/lib/$name" ] && docker cp "coin_appimage_temp:$lib_path" "$APPDIR/usr/lib/$name" 2>/dev/null; then
        COPIED=$((COPIED + 1))
    fi
done
opencv_libs=$(docker exec coin_appimage_temp sh -c 'ls /usr/lib/x86_64-linux-gnu/libopencv_*.so.* 2>/dev/null || ls /lib/x86_64-linux-gnu/libopencv_*.so.* 2>/dev/null' 2>/dev/null) || true
for lib_path in $opencv_libs; do
    [ -z "$lib_path" ] && continue
    name=$(basename "$lib_path")
    [ -f "$APPDIR/usr/lib/$name" ] && continue
    if docker cp "coin_appimage_temp:$lib_path" "$APPDIR/usr/lib/$name" 2>/dev/null; then
        COPIED=$((COPIED + 1))
    fi
done
echo "  Bundled $COPIED libraries from container"

docker stop coin_appimage_temp > /dev/null
docker rm coin_appimage_temp > /dev/null

echo ""

echo "Step 4: Setting up AppImage structure..."
cp appimage/AppRun "$APPDIR/"
chmod +x "$APPDIR/AppRun"

cp appimage/coin-counter.desktop "$APPDIR/"
if [ -f appimage/coin-counter.png ]; then
    cp appimage/coin-counter.png "$APPDIR/"
else
    echo "  Warning: Icon not found, creating placeholder..."
    convert -size 512x512 "xc:#4CAF50" "$APPDIR/coin-counter.png" 2>/dev/null || \
        touch "$APPDIR/coin-counter.png"
fi

chmod +x "$APPDIR"/usr/bin/*

echo ""

echo "Step 5: Checking for appimagetool..."
APPIMAGETOOL="appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo "  Downloading appimagetool..."
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x "$APPIMAGETOOL"
else
    echo "  Found existing appimagetool"
fi
echo ""

echo "Step 6: Building AppImage..."
OUTPUT="coin-counter-x86_64.AppImage"
rm -f "$OUTPUT"

ARCH=x86_64 ./"$APPIMAGETOOL" "$APPDIR" "$OUTPUT"

echo ""
echo "========================================"
echo "  AppImage Build Complete!"
echo "========================================"
echo ""
echo "Output: $OUTPUT"
ls -lh "$OUTPUT"
echo ""
echo "SHA256: $(sha256sum "$OUTPUT" | awk '{print $1}')"
echo ""
echo "To run:"
echo "  ./$OUTPUT"
echo ""
echo "To test on other distros:"
echo "  Copy $OUTPUT to the target system and run it"
echo ""
