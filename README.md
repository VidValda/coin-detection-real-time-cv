# Coin Counter C++

C++ coin detection pipeline (OpenCV): live detection and tracking, calibration, and classifier training. Requires OpenCV 4 (core, imgproc, videoio, highgui, ml).

**Build**

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make
```

**Build with LibTorch (CNN/ResNet classifiers)**  
From the project root, either:

- **Automatic (downloads LibTorch CPU into `build/libtorch`):**
  ```bash
  ./build_with_torch.sh
  ```
- **Using an existing LibTorch** (e.g. from [pytorch.org](https://pytorch.org/get-started/locally/) → C++/LibTorch):
  ```bash
  cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_TORCH=ON -DCMAKE_PREFIX_PATH=/path/to/libtorch
  make
  ```
  If your project path contains spaces, use a path without spaces for LibTorch (e.g. `-DCMAKE_PREFIX_PATH=/tmp/libtorch` with a symlink to the real path).

Then run `python export_torchscript.py` from the project root to generate `coin_cnn_traced.pt` and `coin_resnet18_traced.pt` in `data/models/`. In `coin_counter`, keys `5`/`6` switch to CNN/ResNet18.

**If CNN/ResNet fail to load** with "maximum supported version for reading is 1": your LibTorch is too old. Delete `build/libtorch` and run `./build_with_torch.sh` again (it downloads LibTorch 2.5.1 by default).

**Docker build** uses LibTorch from chunk files `libtorch_part_aa`, `libtorch_part_ab`, ... in the repo (no LFS). To regenerate parts after downloading the zip: `split -b 90m libtorch-2.5.1.zip libtorch_part_`.

---

## Executables

Run from the project root with the data directory set (or from `data/` with `../build/<exe>`). Press `q` to quit unless noted.

```bash
# From project root (recommended):
COIN_DATA_DIR=./data ./build/coin_counter
COIN_DATA_DIR=./data ./build/coin_counter_dl
# Or pass data path as first argument:
./build/coin_counter ./data
```

- **coin_counter** — Live coin detection and tracking. Uses calibration and a classifier (SVM, KNN, RandomForest, NaiveBayes). Keys `1`–`4` switch classifier; `5`/`6` for CNN/ResNet18 when built with LibTorch.
- **coin_counter_dl** — DL-only pipeline (CNN/ResNet18). Keys `1`/`2` switch model.
- **train_acquisition** — Capture labeled crops by zone (6 euro classes, randomized). Writes to `data/training_data_2/` (images + labels + manifest). Keys: `c` capture, `q` quit.
- **train_svm** — Train SVM and other OpenCV classifiers from the manifest; saves models and scaler to `data/models/`. Keys: `s` train and save, `q` quit.
- **camera_calibration** — Capture diameter samples by zone, save calibration to `data/models/coin_calibration_robust.yaml`. Keys: `c` capture, `s` solve and save, `q` quit.

---

## Data directory

All runtime data lives under **`data/`** (see `data/README`):

- **data/models/** — Calibration YAML, classifier YAMLs, `coin_*.pt` and traced models. Produced by `camera_calibration`, `train_svm` / `train_classifier.py`, and `export_torchscript.py`.
- **data/training_data_2/** — Images, JSON labels, and manifest for DL training and `train_svm`.
- **data/videos/** — Test videos (e.g. `test1.mp4`, `test2.mp4`) when `USE_TEST_VIDEOS` is enabled in `include/config.hpp`.

Set `COIN_DATA_DIR` to the path of `data` (or pass it as the first argument to any executable). If unset, binaries look for paths relative to the current working directory (e.g. run from `data/` with `../build/coin_counter`).
