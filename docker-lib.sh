#!/usr/bin/env bash

detect_platform() {
    OS_TYPE="$(uname -s)"
    case "${OS_TYPE}" in
        Linux*)     PLATFORM="linux";;
        Darwin*)    PLATFORM="macos";;
        CYGWIN*|MINGW*|MSYS*) PLATFORM="windows";;
        *)          PLATFORM="unknown";;
    esac

    if [[ "$PLATFORM" == "linux" ]] && grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
        PLATFORM="wsl2"
    fi

    export PLATFORM
}

setup_display_linux() {
    xhost +local:docker 2>/dev/null || true
    DISPLAY_ENV="-e DISPLAY=$DISPLAY"
    DISPLAY_VOLUME="-v /tmp/.X11-unix:/tmp/.X11-unix:rw"
    export DISPLAY_ENV DISPLAY_VOLUME
}

setup_display_macos() {
    if ! pgrep -x "XQuartz" > /dev/null 2>&1; then
        echo "⚠️  Warning: XQuartz not detected."
        echo "   For GUI display, install XQuartz: https://www.xquartz.org/"
        echo "   After installation:"
        echo "     1. Launch XQuartz: open -a XQuartz"
        echo "     2. In XQuartz preferences, enable 'Allow connections from network clients'"
        echo "     3. Run: xhost +localhost"
        echo ""
    fi

    DISPLAY_ENV="-e DISPLAY=host.docker.internal:0"
    DISPLAY_VOLUME=""
    export DISPLAY_ENV DISPLAY_VOLUME
}

setup_display_wsl2() {
    if [[ -n "$WAYLAND_DISPLAY" ]] || [[ -S "/tmp/.X11-unix/X0"     ]]; then
        DISPLAY_ENV="-e DISPLAY=$DISPLAY"
        DISPLAY_VOLUME="-v /tmp/.X11-unix:/tmp/.X11-unix:rw"
    else
        WINDOWS_HOST=$(grep nameserver /etc/resolv.conf | awk '{print $2}' 2>/dev/null || echo "localhost")
        DISPLAY_ENV="-e DISPLAY=${WINDOWS_HOST}:0"
        DISPLAY_VOLUME=""

        echo "ℹ️  Note: Using Windows X server at ${WINDOWS_HOST}:0"
        echo "   Make sure an X server (VcXsrv or Xming) is running on Windows"
        echo ""
    fi
    export DISPLAY_ENV DISPLAY_VOLUME
}

setup_display_windows() {
    echo "⚠️  Warning: Running on native Windows"
    echo "   An X server (VcXsrv or Xming) is required for GUI display"
    echo ""

    DISPLAY_ENV="-e DISPLAY=host.docker.internal:0"
    DISPLAY_VOLUME=""
    export DISPLAY_ENV DISPLAY_VOLUME
}

discover_cameras() {
    if [[ "$PLATFORM" == "linux" ]] || [[ "$PLATFORM" == "wsl2" ]]; then
        echo ""
        echo "Available cameras:"
        local found_any=false
        for dev in /dev/video*; do
            if [ -c "$dev" ]; then
                found_any=true
                if command -v v4l2-ctl &>/dev/null; then
                    local name=$(v4l2-ctl -d "$dev" --info 2>/dev/null | grep "Card type" | cut -d: -f2 | xargs)
                    if [[ -n "$name" ]]; then
                        echo "  $dev: $name"
                    else
                        echo "  $dev"
                    fi
                else
                    echo "  $dev"
                fi
            fi
        done

        if ! $found_any; then
            echo "  (none found)"
        fi
        echo ""
    fi
}

setup_camera_linux() {
    if [ "$USE_CAMERA" = "true" ]; then
        if [ -e "$CAMERA_DEV" ]; then
            DEVICE_FLAG="--device=$CAMERA_DEV:$CAMERA_DEV"
            export DEVICE_FLAG
            return 0
        else
            echo "⚠️  Warning: Camera device $CAMERA_DEV not found."
            discover_cameras
            read -p "Continue without camera (use video mode)? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                USE_CAMERA=false
                DEVICE_FLAG=""
                export USE_CAMERA DEVICE_FLAG
                return 0
            else
                return 1
            fi
        fi
    else
        DEVICE_FLAG=""
        export DEVICE_FLAG
        return 0
    fi
}

setup_camera_macos() {
    if [ "$USE_CAMERA" = "true" ]; then
        echo "⚠️  Warning: Direct camera passthrough is not supported on macOS with Docker Desktop."
        echo ""
        echo "Options:"
        echo "  1. Use video mode instead (default - recommended)"
        echo "  2. Use camera streaming tools (e.g., ffmpeg to network stream)"
        echo "  3. Run natively on macOS without Docker"
        echo ""
        read -p "Continue in video mode? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            USE_CAMERA=false
            DEVICE_FLAG=""
            export USE_CAMERA DEVICE_FLAG
            return 0
        else
            return 1
        fi
    else
        DEVICE_FLAG=""
        export DEVICE_FLAG
        return 0
    fi
}

setup_camera_wsl2() {
    if [ "$USE_CAMERA" = "true" ]; then
        echo "⚠️  Warning: Camera passthrough has limited support on WSL2."
        echo ""

        # Check if camera device exists
        if [ -e "$CAMERA_DEV" ]; then
            echo "ℹ️  Camera device $CAMERA_DEV found, attempting to use it."
            DEVICE_FLAG="--device=$CAMERA_DEV:$CAMERA_DEV"
            export DEVICE_FLAG
            return 0
        else
            echo "Camera device not found. WSL2 typically doesn't support USB device passthrough."
            echo "Consider using video mode or running on native Linux."
            echo ""
            read -p "Continue in video mode? (Y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                USE_CAMERA=false
                DEVICE_FLAG=""
                export USE_CAMERA DEVICE_FLAG
                return 0
            else
                return 1
            fi
        fi
    else
        DEVICE_FLAG=""
        export DEVICE_FLAG
        return 0
    fi
}

setup_camera_windows() {
    if [ "$USE_CAMERA" = "true" ]; then
        echo "⚠️  Warning: Camera passthrough is not supported on native Windows with Docker."
        echo "   Please use video mode or run on WSL2/Linux."
        echo ""
        USE_CAMERA=false
    fi
    DEVICE_FLAG=""
    export USE_CAMERA DEVICE_FLAG
}

setup_network_linux() {
    NETWORK_FLAG="--network host"
    export NETWORK_FLAG
}

setup_network_nonlinux() {
    NETWORK_FLAG=""
    export NETWORK_FLAG
}

setup_platform() {
    detect_platform

    case "$PLATFORM" in
        linux)
            setup_display_linux
            setup_network_linux
            ;;
        macos)
            setup_display_macos
            setup_network_nonlinux
            ;;
        wsl2)
            setup_display_wsl2
            setup_network_nonlinux
            ;;
        windows)
            setup_display_windows
            setup_network_nonlinux
            ;;
        *)
            echo "⚠️  Warning: Unknown platform detected ($OS_TYPE)"
            echo "   Defaulting to Linux configuration, but issues may occur."
            echo ""
            setup_display_linux
            setup_network_linux
            ;;
    esac
}

cleanup_display() {
    if [[ "$PLATFORM" == "linux" ]]; then
        xhost -local:docker 2>/dev/null || true
    fi
}

get_platform_display_name() {
    case "$PLATFORM" in
        linux)   echo "Linux (Native Docker)" ;;
        macos)   echo "macOS (Docker Desktop)" ;;
        wsl2)    echo "WSL2 (Windows Subsystem for Linux)" ;;
        windows) echo "Windows (Native)" ;;
        *)       echo "Unknown ($OS_TYPE)" ;;
    esac
}

get_platform_features() {
    case "$PLATFORM" in
        linux)
            echo "✅ Full support: Camera, Display, All features"
            ;;
        macos)
            echo "⚠️  Limited: Display via XQuartz, No camera support"
            ;;
        wsl2)
            echo "⚠️  Limited: Display via WSLg/X server, Limited camera support"
            ;;
        windows)
            echo "⚠️  Limited: Display via X server, No camera support"
            ;;
        *)
            echo "❓ Unknown platform"
            ;;
    esac
}
