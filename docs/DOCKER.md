# Docker Usage Guide

This project provides a Docker container for easy deployment without installing OpenCV or LibTorch locally. Run the coin counter on any computer with Docker installed.

---

## Quick Start

### 1. Build and Run (One Command)

The easiest way to get started:

```bash
./docker-build-and-run.sh
```

This builds the Docker image and automatically starts the coin counter.

---

### 2. Build Image

Build the Docker image with full capabilities (includes LibTorch for deep learning):

```bash
./docker-build.sh
```

This creates the `coin-counter:latest` image (~1.5GB) including:
- OpenCV 4.5.4
- LibTorch 2.5.1 CPU
- All 6 classifiers (SVM, KNN, RF, NB, CNN, ResNet18)

**Build time:** 10-15 minutes (downloads ~200MB LibTorch archive)

---

### 3. Run Coin Counter

**Using helper script (recommended):**

```bash
./docker-run.sh coin-counter
```

**Using docker-compose:**

```bash
docker-compose up coin-counter
```

**Using docker run directly:**

```bash
xhost +local:docker

docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v $(pwd)/data:/app/data:ro \
  --device=/dev/video2:/dev/video2 \
  --network host \
  coin-counter:latest

xhost -local:docker
```

---

### 4. Training Tools

Run training executables with write access to data:

```bash
# Capture training samples
./docker-train.sh coin-counter train_acquisition

# Train SVM classifier
./docker-train.sh coin-counter train_svm

# Camera calibration
./docker-train.sh coin-counter camera_calibration
```

Or with docker-compose:

```bash
# Run train_acquisition
docker-compose --profile train run --rm coin-counter-train

# Run different training command
docker-compose --profile train run --rm coin-counter-train train_svm
```

---

## What's Displayed

When you run the coin counter, **two separate windows** appear:

1. **Camera View** (left) - Shows `test1.mp4` with green paper detection outline
2. **Coin Detection** (right) - Shows warped paper view with:
   - Detected coins (colored circles)
   - Coin diameters in mm
   - Info box (top-left): Coin count, total value, current classifier
   - Keyboard controls legend (bottom-left)
   - FPS counter (top-right)

The application automatically plays `data/videos/test1.mp4` in a loop (no camera needed).

---

## Keyboard Controls

While the application is running:

| Key | Action |
|-----|--------|
| `1` | Switch to SVM classifier |
| `2` | Switch to KNN classifier |
| `3` | Switch to Random Forest classifier |
| `4` | Switch to Naive Bayes classifier |
| `5` | Switch to CNN classifier (deep learning) |
| `6` | Switch to ResNet18 classifier (deep learning) |
| `t` | Toggle performance timings display |
| `q` | Quit application |

The keyboard legend is displayed in the bottom-left corner of the Coin Detection window.

---

## Configuration

### Camera Device

Default camera is `/dev/video2` (not used when playing test video). Change via environment variable:

```bash
CAMERA_DEV=/dev/video0 ./docker-run.sh coin-counter
```

Or edit `docker-compose.yml` devices section:

```yaml
devices:
  - /dev/video0:/dev/video0  # Change from video2 to video0
```

To find your camera device:

```bash
ls -l /dev/video*
v4l2-ctl --list-devices  # If installed
```

---

### Data Directory

By default, `./data` is mounted as `/app/data` inside the container.

**Option 1: Volume mount (default, recommended)**

Allows updating models without rebuilding:

```yaml
volumes:
  - ./data:/app/data:ro  # Read-only for inference
  - ./data:/app/data:rw  # Read-write for training
```

**Option 2: Bake data into image**

For self-contained deployment, modify Dockerfile:

```dockerfile
# Add after creating /app/data directory
COPY data/ /app/data/
```

Then rebuild the image. Suitable when data won't change.

---

### X11 Display

**Linux hosts:** Works out of the box with X11 socket mounting.

The helper scripts automatically handle `xhost` permissions:
- `xhost +local:docker` before running
- `xhost -local:docker` after stopping

**Manual X11 setup:**

```bash
xhost +local:docker
# ... run container ...
xhost -local:docker
```

**macOS / Windows:**

X11 forwarding not natively supported. Options:
1. Install XQuartz (macOS) or VcXsrv (Windows) and set DISPLAY
2. Use VNC server inside container (requires Dockerfile modification)
3. SSH with X11 forwarding

**Remote access:**

For headless servers, consider:
- VNC server in container
- X11 forwarding over SSH
- Web-based visualization (requires code modification)

---

## Troubleshooting

### Display Issues

**Problem:** `cannot open display: :0` or blank windows

**Solution:**

```bash
# Enable X11 access
xhost +local:docker
./docker-run.sh coin-counter

# If still fails, check DISPLAY variable
echo $DISPLAY  # Should show :0 or :1

# Try setting explicitly
DISPLAY=:0 ./docker-run.sh coin-counter
```

### Camera Access Denied

**Problem:** `Failed to open camera` or permission errors

**Solution 1:** Add your user to video group on host

```bash
sudo usermod -aG video $USER
# Log out and back in for changes to take effect
```

**Solution 2:** Check camera device path

```bash
ls -l /dev/video*
# Use the correct device
CAMERA_DEV=/dev/video0 ./docker-run.sh coin-counter
```

**Solution 3:** Run with privileged mode (less secure)

```bash
docker run --privileged ...
```

### Permission Errors with Data Volume

**Problem:** Cannot read models or write training data

Container runs as UID 1000 (coinuser). Ensure host data directory has correct permissions:

```bash
# For read-only inference
chmod -R a+r data/

# For training (write access needed)
chmod -R a+rw data/models data/training_data_2

# Or change ownership to UID 1000
sudo chown -R 1000:1000 data/
```

### Video File Not Found

**Problem:** Application fails to start or shows black screen

The application expects `data/videos/test1.mp4` to exist. Ensure:

```bash
# Check if test video exists
ls -lh data/videos/test1.mp4

# If missing, the application will try camera instead
# To disable test videos and force camera:
# Edit include/config.hpp: USE_TEST_VIDEOS = false
```

### Windows Don't Appear Side-by-Side

**Problem:** Both windows overlap or only one appears

Your screen resolution may be too small. The windows are positioned at:
- Camera View: x=50
- Coin Detection: x=1050

Each window can be up to 960px wide, requiring ~2000px horizontal space.

**Solution:** Manually reposition windows or use a larger display (1920×1080 recommended).

---

## Advanced Usage

### Run Specific Executable

```bash
# Run camera calibration
./docker-run.sh coin-counter camera_calibration

# Run training acquisition
./docker-train.sh coin-counter train_acquisition

# Run SVM training
./docker-train.sh coin-counter train_svm
```

### Interactive Shell

Debug or explore inside the container:

```bash
docker run -it --rm \
  -v $(pwd)/data:/app/data:rw \
  coin-counter:latest \
  bash

# Inside container:
ls /app/bin/        # List executables
ls /app/data/       # List data
coin_counter --help # Run commands
```

### Custom Data Path

Use a different data directory:

```bash
docker run -it --rm \
  -e COIN_DATA_DIR=/custom/path \
  -v /host/custom/data:/custom/path:ro \
  coin-counter:latest
```

### Build Without Cache

Force complete rebuild:

```bash
docker build --no-cache -t coin-counter:latest .
```

### Save and Load Images

Export image to share without registry:

```bash
# Save to tar file
docker save coin-counter:latest -o coin-counter.tar

# Load on another machine
docker load -i coin-counter.tar
```

### Push to Registry

Share images via Docker Hub or GitHub Container Registry:

```bash
# Tag for registry
docker tag coin-counter:latest yourusername/coin-counter:latest

# Push to Docker Hub
docker login
docker push yourusername/coin-counter:latest

# Pull on another machine
docker pull yourusername/coin-counter:latest
```

---

## Architecture Notes

### Base Image

- **OS:** Ubuntu 22.04 LTS (Jammy)
- **Support:** Until 2027
- **Reason:** Provides OpenCV 4.5.4 via apt packages

### Dependencies

**Build stage:**
- build-essential (gcc, g++, make)
- cmake 3.22+
- wget, unzip (for LibTorch download)
- libopencv-dev (headers and development libraries)

**Runtime stage:**
- libopencv-core4.5d
- libopencv-imgproc4.5d
- libopencv-highgui4.5d
- libopencv-videoio4.5d
- libopencv-ml4.5d
- libopencv-imgcodecs4.5d
- libgomp1 (OpenMP for parallel processing)
- LibTorch 2.5.1 CPU (~735MB)

### Security

- **Non-root user:** All processes run as `coinuser` (UID 1000)
- **Minimal packages:** No build tools in final image
- **Read-only data:** Inference uses `:ro` mount by default
- **No secrets:** Models and config mounted externally
- **Device access:** Limited to specific camera device

### Multi-Stage Build

Three stages minimize final image size:

1. **builder** - Compiles code with LibTorch (~1.5GB with build tools)
2. **runtime-base** - OpenCV runtime libs (~400MB)
3. **runtime** - Final image with executables only (~1.5GB)

Only the final runtime stage is included in the image.

---

## Performance

### CPU Usage

- SVM classifiers: Low CPU (~10-20% on quad-core)
- CNN/ResNet18: High CPU (~60-80% without GPU)

This build uses LibTorch CPU version. For GPU acceleration, modify Dockerfile to download CUDA-enabled LibTorch.

### Memory Usage

- Runtime: ~500-800MB RAM (ResNet18 loaded)

### Latency

- Paper detection: ~50ms (every 10 frames)
- Coin detection: ~100ms (every 30 frames)
- Classification: ~5ms (SVM), ~50ms (CNN CPU)

---

## Image Size

- **coin-counter:latest:** ~1.5GB (includes OpenCV + LibTorch + CNN/ResNet)

---

## FAQ

**Q: Can I run this on macOS or Windows?**

A: Yes, with limitations. Docker Desktop works, but X11 display requires additional setup (XQuartz/VcXsrv). Camera access may also need configuration.

**Q: Do I need to rebuild the image when I update models?**

A: No. Models are in the mounted `data/` directory. Update files on host and restart container.

**Q: Why does it use test1.mp4 instead of camera?**

A: For ease of demonstration and testing. The application is configured to use `data/videos/test1.mp4` by default. To use camera, disable test videos in `include/config.hpp` or remove the test video file.

**Q: Can I use GPU acceleration?**

A: The current build uses CPU LibTorch. For GPU, modify Dockerfile to download CUDA-enabled LibTorch and add NVIDIA runtime (`--gpus all`).

**Q: Why is the image so large?**

A: LibTorch is ~735MB. This is normal for deep learning frameworks. The image includes all 6 classifiers (SVM + deep learning).

**Q: Can I run multiple containers simultaneously?**

A: Yes, but each needs a unique name and camera device. Modify `docker-compose.yml` or use `--name` with different values.

---

## Support

For issues with Docker setup:
1. Check this troubleshooting guide
2. Verify Docker is installed: `docker --version`
3. Check system requirements: Linux with X11, camera device available
4. Review container logs: `docker logs <container_name>`

For application issues (detection, classification), see main README.md.

---

## License

Same as the main project. See LICENSE file.
