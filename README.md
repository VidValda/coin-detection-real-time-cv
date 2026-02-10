# Coin Counter

Real-time coin detection and counting system using OpenCV and optional LibTorch.

## Dependencies

### C++ (required)
```bash
sudo apt install build-essential cmake libopencv-dev
```

### LibTorch (optional — for CNN/ResNet classifiers)
```bash
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
mkdir build && cd build && cmake .. && make
./coin_counter ../data
```

### macOS
```bash
brew install cmake opencv
mkdir build && cd build && cmake .. && make
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

### With LibTorch (optional — enables CNN/ResNet classifiers)
Add to the cmake command:
```
-DLibTorch_DIR=/path/to/libtorch -DUSE_TORCH=ON
```
