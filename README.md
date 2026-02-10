# Coin Counter

Real-time coin detection and counting system using OpenCV and LibTorch.

## Clone Repository

```bash
git clone https://github.com/VidValda/coin-detection-real-time-cv.git
cd coin-detection-real-time-cv
```

## Dependencies

### C++ (required)

```bash
sudo apt install build-essential cmake libopencv-dev
```

### LibTorch

```bash
# Recomendation: place it inside the root of the project
wget https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.5.1%2Bcpu.zip
unzip libtorch-*.zip
```

### Python (for training only)

```bash
pip install -r requirements.txt
```

## Build & Run

### Linux

```bash
#This makes the asumption that libtorch is on the root of the project
mkdir build && cd build && cmake .. -DLibTorch_DIR=./libtorch -DUSE_TORCH=ON && make
./coin_counter ../data
```

### macOS

```bash
brew install cmake opencv
mkdir build && cd build && cmake .. -DLibTorch_DIR=./libtorch -DUSE_TORCH=ON && make
./coin_counter ../data
```

### Windows

Install [vcpkg](https://github.com/microsoft/vcpkg), then:

```powershell
vcpkg install opencv4
mkdir build && cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=[vcpkg-root]/scripts/buildsystems/vcpkg.cmake
cmake --build . --config Release
.\Release\coin_counter.exe ..\data
```
