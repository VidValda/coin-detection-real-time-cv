# Docker Usage Guide

This project provides Docker containers for easy deployment without installing OpenCV or LibTorch locally. Run the coin counter on any computer with Docker installed.

---

## Quick Start

### 1. Build Images

Build both variants (SVM-only and LibTorch-enabled):

```bash
./docker-build.sh
```

This creates two images:
- `coin-counter:svm` - Lightweight SVM-only variant (~500MB)
- `coin-counter:dl` - Full variant with LibTorch (~1.5GB)

**Build time:**
- SVM variant: 3-5 minutes
- DL variant: 10-15 minutes (downloads LibTorch)

Or build individually:

```bash
# Lightweight SVM-only
docker build --build-arg BUILD_WITH_TORCH=OFF -t coin-counter:svm .

# Full with LibTorch (includes CNN/ResNet18)
docker build --build-arg BUILD_WITH_TORCH=ON -t coin-counter:dl .
```

---

### 2. Run Coin Counter

**Using helper script (recommended):**

```bash
# SVM classifier
./docker-run.sh coin-counter:svm

# Deep learning classifier
./docker-run.sh coin-counter:dl
```

**Using docker-compose:**

```bash
# SVM variant
docker-compose --profile svm up coin-counter-svm

# Deep learning variant
docker-compose --profile dl up coin-counter-dl
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
  coin-counter:svm

xhost -local:docker
```

---

### 3. Training Tools

Run training executables with write access to data:

```bash
# Capture training samples
./docker-train.sh coin-counter:svm train_acquisition

# Train SVM classifier
./docker-train.sh coin-counter:svm train_svm

# Camera calibration
./docker-train.sh coin-counter:svm camera_calibration
```

Or with docker-compose:

```bash
# Run train_acquisition
docker-compose --profile train run --rm coin-counter-train

# Run different training command
docker-compose --profile train run --rm coin-counter-train train_svm
```

---

## Configuration

### Camera Device

Default camera is `/dev/video2`. Change via environment variable:

```bash
CAMERA_DEV=/dev/video0 ./docker-run.sh coin-counter:svm
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

## Keyboard Controls

Once the coin counter is running:

| Key | Action |
|-----|--------|
| `1` | Switch to SVM classifier |
| `2` | Switch to KNN classifier |
| `3` | Switch to Random Forest classifier |
| `4` | Switch to Naive Bayes classifier |
| `5` | Switch to CNN classifier (DL variant only) |
| `6` | Switch to ResNet18 classifier (DL variant only) |
| `t` | Toggle performance timings display |
| `q` | Quit application |

---

## Troubleshooting

### Display Issues

**Problem:** `cannot open display: :0` or blank window

**Solution:**

```bash
# Enable X11 access
xhost +local:docker
./docker-run.sh coin-counter:svm

# If still fails, check DISPLAY variable
echo $DISPLAY  # Should show :0 or :1

# Try setting explicitly
DISPLAY=:0 ./docker-run.sh coin-counter:svm
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
CAMERA_DEV=/dev/video0 ./docker-run.sh
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

### LibTorch Model Loading Fails

**Problem:** DL variant cannot load `.pt` models

**Solution:** Ensure models are exported with compatible PyTorch version (2.5.1):

```bash
# On host with Python and PyTorch installed
python export_torchscript.py

# Or rebuild models inside container
docker run -it --rm \
  -v $(pwd)/data:/app/data:rw \
  coin-counter:dl \
  bash
# Then run export script inside container
```

### Image Too Large

**Current sizes:**
- `coin-counter:svm`: ~500MB
- `coin-counter:dl`: ~1.5GB

**To reduce size:**

1. Use SVM variant only (skip DL build)
2. Remove test videos from data directory before COPY
3. Use `docker build --squash` (experimental feature)
4. Multi-arch builds for specific platform only

### Container Won't Start

**Check logs:**

```bash
docker logs coin_counter_svm
# or
docker-compose logs coin-counter-svm
```

**Check image exists:**

```bash
docker images coin-counter
```

**Rebuild from scratch:**

```bash
docker build --no-cache -t coin-counter:svm .
```

---

## Advanced Usage

### Run Specific Executable

```bash
# Run camera calibration
./docker-run.sh coin-counter:svm camera_calibration

# Run training acquisition
./docker-train.sh coin-counter:svm train_acquisition

# Run SVM training
./docker-train.sh coin-counter:svm train_svm
```

### Interactive Shell

Debug or explore inside the container:

```bash
docker run -it --rm \
  -v $(pwd)/data:/app/data:rw \
  coin-counter:svm \
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
  coin-counter:svm
```

### Change Camera Index via CLI

The executables accept camera index as second argument:

```bash
# Use camera 0 instead of default 2
docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v $(pwd)/data:/app/data:ro \
  --device=/dev/video0:/dev/video0 \
  --network host \
  coin-counter:svm \
  coin_counter /app/data 0
```

### Build Without Cache

Force complete rebuild:

```bash
docker build --no-cache --build-arg BUILD_WITH_TORCH=OFF -t coin-counter:svm .
```

### Save and Load Images

Export image to share without registry:

```bash
# Save to tar file
docker save coin-counter:svm -o coin-counter-svm.tar

# Load on another machine
docker load -i coin-counter-svm.tar
```

### Push to Registry

Share images via Docker Hub or GitHub Container Registry:

```bash
# Tag for registry
docker tag coin-counter:svm yourusername/coin-counter:svm

# Push to Docker Hub
docker login
docker push yourusername/coin-counter:svm

# Pull on another machine
docker pull yourusername/coin-counter:svm
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

**LibTorch (DL variant only):**
- Version: 2.5.1 CPU
- Download: ~200MB zip
- Extracted: ~735MB
- ABI: cxx11 (matches system C++ ABI)

### Security

- **Non-root user:** All processes run as `coinuser` (UID 1000)
- **Minimal packages:** No build tools in final image
- **Read-only data:** Inference uses `:ro` mount by default
- **No secrets:** Models and config mounted externally
- **Device access:** Limited to specific camera device

### Multi-Stage Build

Three stages minimize final image size:

1. **builder** - Compiles code (~1.5GB with build tools)
2. **runtime-base** - OpenCV runtime libs (~400MB)
3. **runtime** - Final image with executables only (~500MB SVM, ~1.5GB DL)

Only the final runtime stage is included in the image.

---

## Performance

### CPU Usage

- SVM classifiers: Low CPU (~10-20% on quad-core)
- CNN/ResNet18: High CPU (~60-80% without GPU)

This build uses LibTorch CPU version. For GPU acceleration, modify Dockerfile to download CUDA-enabled LibTorch.

### Memory Usage

- SVM variant: ~200-300MB RAM
- DL variant: ~500-800MB RAM (ResNet18 loaded)

### Latency

- Paper detection: ~50ms (every 10 frames)
- Coin detection: ~100ms (every 30 frames)
- Classification: ~5ms (SVM), ~50ms (CNN CPU)

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Docker Images

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build SVM variant
        run: docker build --build-arg BUILD_WITH_TORCH=OFF -t coin-counter:svm .

      - name: Build DL variant
        run: docker build --build-arg BUILD_WITH_TORCH=ON -t coin-counter:dl .

      - name: Test SVM image
        run: docker run --rm coin-counter:svm coin_counter --help || true
```

---

## Differences from Native Build

| Aspect | Native Build | Docker |
|--------|-------------|--------|
| Dependencies | Manual install | Automatic |
| Reproducibility | System-dependent | Identical everywhere |
| Isolation | Shares host libs | Isolated container |
| X11 | Direct | Socket mount needed |
| Camera | Direct access | Device passthrough |
| Data | Local paths | Volume mount |
| Build time | 2-3 min | 5-15 min (includes downloads) |
| Disk space | ~2GB (with LibTorch) | ~1.5GB (image only) |

---

## FAQ

**Q: Can I run this on macOS or Windows?**

A: Yes, with limitations. Docker Desktop works, but X11 display requires additional setup (XQuartz/VcXsrv). Camera access may also need configuration.

**Q: Do I need to rebuild the image when I update models?**

A: No. Models are in the mounted `data/` directory. Update files on host and restart container.

**Q: Can I run multiple containers simultaneously?**

A: Yes, but each needs a unique name and camera device. Modify `docker-compose.yml` or use `--name` with different values.

**Q: How do I update to a newer LibTorch version?**

A: Edit `build_with_torch.sh` to change the download URL, then rebuild the DL image.

**Q: Can I use GPU acceleration?**

A: The current build uses CPU LibTorch. For GPU, modify Dockerfile to download CUDA-enabled LibTorch and add NVIDIA runtime (`--gpus all`).

**Q: Why is the image so large?**

A: LibTorch is ~735MB. The SVM variant (without LibTorch) is only ~500MB. This is normal for deep learning frameworks.

**Q: Can I reduce build time?**

A: Use `docker build --build-arg BUILD_WITH_TORCH=OFF` to skip LibTorch download. Enable Docker BuildKit for better caching.

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
