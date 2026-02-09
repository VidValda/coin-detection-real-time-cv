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

docker create --name coin_appimage_temp "$IMAGE_NAME" > /dev/null
echo "  Extracting executables..."
docker cp coin_appimage_temp:/app/bin/coin_counter "$APPDIR/usr/bin/"
docker cp coin_appimage_temp:/app/bin/camera_calibration "$APPDIR/usr/bin/"
docker cp coin_appimage_temp:/app/bin/train_svm "$APPDIR/usr/bin/"
docker cp coin_appimage_temp:/app/bin/train_acquisition "$APPDIR/usr/bin/"

echo "  Extracting LibTorch libraries..."
docker cp coin_appimage_temp:/app/lib/. "$APPDIR/usr/lib/"

echo "  Extracting data files from Docker..."
docker cp coin_appimage_temp:/app/data/. "$APPDIR/usr/share/coin-counter/data/" 2>/dev/null || true

docker rm coin_appimage_temp > /dev/null

echo "  Copying data files from host (models, configs)..."
if [ -d "$PROJECT_ROOT/data" ]; then
    cp -r "$PROJECT_ROOT/data"/* "$APPDIR/usr/share/coin-counter/data/" 2>/dev/null || true
    echo "    ✓ Copied models and data files"
else
    echo "    ⚠ Warning: data/ directory not found on host"
fi
echo ""

echo "Step 3: Bundling dependencies..."

copy_libs() {
    local lib="$1"
    if [ ! -f "$lib" ]; then
        return
    fi

    local libname=$(basename "$lib")

    if [ -f "$APPDIR/usr/lib/$libname" ]; then
        return
    fi

    case "$libname" in
        libc.so*|libm.so*|libdl.so*|libpthread.so*|librt.so*|ld-linux*)
            return ;;
        libgcc_s.so*|libstdc++.so*)
            return ;;
        libX11.so*|libxcb.so*|libXext.so*|libXrender.so*|libXau.so*)
            return ;;
        libGL.so*|libGLX.so*|libEGL.so*|libdrm.so*)
            return ;;
        libnvidia*|libcuda*)
            return ;;
    esac

    cp -L "$lib" "$APPDIR/usr/lib/" 2>/dev/null || true
}

echo "  Bundling OpenCV libraries..."
for lib in /lib/x86_64-linux-gnu/libopencv_*.so.4.5d; do
    [ -f "$lib" ] && copy_libs "$lib"
done

echo "  Bundling GTK libraries..."
for lib in \
    /lib/x86_64-linux-gnu/libgtk-3.so.0 \
    /lib/x86_64-linux-gnu/libgdk-3.so.0 \
    /lib/x86_64-linux-gnu/libcairo.so.2 \
    /lib/x86_64-linux-gnu/libgdk_pixbuf-2.0.so.0 \
    /lib/x86_64-linux-gnu/libgobject-2.0.so.0 \
    /lib/x86_64-linux-gnu/libglib-2.0.so.0 \
    /lib/x86_64-linux-gnu/libpango-1.0.so.0 \
    /lib/x86_64-linux-gnu/libpangocairo-1.0.so.0 \
    /lib/x86_64-linux-gnu/libgio-2.0.so.0 \
    /lib/x86_64-linux-gnu/libgmodule-2.0.so.0 \
    /lib/x86_64-linux-gnu/libatk-1.0.so.0; do
    [ -f "$lib" ] && copy_libs "$lib"
done

echo "  Bundling media libraries..."
for lib in \
    /lib/x86_64-linux-gnu/libavcodec.so.58 \
    /lib/x86_64-linux-gnu/libavformat.so.58 \
    /lib/x86_64-linux-gnu/libavutil.so.56 \
    /lib/x86_64-linux-gnu/libswscale.so.5 \
    /lib/x86_64-linux-gnu/libswresample.so.3; do
    [ -f "$lib" ] && copy_libs "$lib"
done

echo "  Bundling GStreamer libraries..."
for lib in \
    /lib/x86_64-linux-gnu/libgstreamer-1.0.so.0 \
    /lib/x86_64-linux-gnu/libgstbase-1.0.so.0 \
    /lib/x86_64-linux-gnu/libgstapp-1.0.so.0 \
    /lib/x86_64-linux-gnu/libgstvideo-1.0.so.0; do
    [ -f "$lib" ] && copy_libs "$lib"
done

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
