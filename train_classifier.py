from __future__ import annotations

import json
from pathlib import Path
import numpy as np
import cv2

REPO_ROOT = Path(__file__).resolve().parent
DATA_DIR = REPO_ROOT / "data"
MODELS_DIR = DATA_DIR / "models"
TRAINING_BASE = DATA_DIR / "training_data_2"
MANIFEST_PATH = TRAINING_BASE / "manifest.csv"

CLASSIFIER_MODEL_NAMES = ["coin_svm.yaml", "coin_knn.yaml", "coin_rtrees.yaml", "coin_nb.yaml"]
SCALER_PATH = "coin_scaler.yaml"
DEFAULT_FILE = "classifier_default.txt"
MODEL_TYPE_NAMES = ["SVM", "KNN", "RandomForest", "NaiveBayes"]

LABEL_TO_CLASS_ID = {"20cent": 0, "10cent": 1, "1euro": 2, "1cent": 3, "2cent": 4, "5cent": 5}
SCALE_FACTOR_FALLBACK = 5.46104  # Config::SCALE_FACTOR in config.hpp


def load_ratio_px_to_mm() -> float:
    cal_path = MODELS_DIR / "coin_calibration_robust.yaml"
    if cal_path.is_file():
        fs = cv2.FileStorage(str(cal_path), cv2.FILE_STORAGE_READ)
        if fs.isOpened():
            node = fs.getNode("ratio_px_to_mm")
            if not node.empty():
                val = node.real()
                fs.release()
                return float(val)
            fs.release()
    return 1.0 / SCALE_FACTOR_FALLBACK


def extract_crop(
    bgr: np.ndarray, cx: int, cy: int, crop_size: int, h: int, w: int
) -> np.ndarray:
    half = crop_size // 2
    x1 = cx - half
    y1 = cy - half
    x2 = cx + half
    y2 = cy + half
    out = np.zeros((crop_size, crop_size, 3), dtype=bgr.dtype)
    src_x1 = max(0, x1)
    src_y1 = max(0, y1)
    src_x2 = min(w, x2)
    src_y2 = min(h, y2)
    dst_x1 = src_x1 - x1
    dst_y1 = src_y1 - y1
    dst_x2 = dst_x1 + (src_x2 - src_x1)
    dst_y2 = dst_y1 + (src_y2 - src_y1)
    if dst_x2 > dst_x1 and dst_y2 > dst_y1:
        out[dst_y1:dst_y2, dst_x1:dst_x2] = bgr[src_y1:src_y2, src_x1:src_x2]
    return out


def load_manifest(path: Path) -> list[tuple[str, int, float]]:
    rows = []
    if not path.is_file():
        return rows
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    if not lines or "path" not in lines[0]:
        return rows
    for line in lines[1:]:
        line = line.strip()
        if not line:
            continue
        parts = line.split(",")
        if len(parts) < 3:
            continue
        try:
            rel_path = parts[0].strip()
            class_id = int(parts[1].strip())
            sdiam = parts[2].strip().rstrip("\r\n ")
            diameter_mm = float(sdiam)
            rows.append((rel_path, class_id, diameter_mm))
        except (ValueError, IndexError):
            continue
    return rows


def sample_mean_lab_inside_circle(bgr: np.ndarray, center_xy: tuple[int, int], radius_px: int) -> np.ndarray | None:
    h, w = bgr.shape[:2]
    cx, cy = center_xy
    inner_r = max(2, int(radius_px * 0.7))
    y0 = max(0, cy - inner_r)
    y1 = min(h, cy + inner_r + 1)
    x0 = max(0, cx - inner_r)
    x1 = min(w, cx + inner_r + 1)
    if y1 <= y0 or x1 <= x0:
        return None
    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    roi = lab[y0:y1, x0:x1]
    mask = np.zeros((roi.shape[0], roi.shape[1]), dtype=np.uint8)
    for y in range(roi.shape[0]):
        for x in range(roi.shape[1]):
            gx = x0 + x - cx
            gy = y0 + y - cy
            if gx * gx + gy * gy <= inner_r * inner_r:
                mask[y, x] = 255
    mean_val = cv2.mean(roi, mask=mask)
    return np.array([mean_val[0], mean_val[1], mean_val[2]], dtype=np.float64)


def extract_features(bgr: np.ndarray, diameter_mm: float) -> np.ndarray | None:
    if bgr is None or bgr.size == 0:
        return None
    h, w = bgr.shape[:2]
    cx, cy = w // 2, h // 2
    radius_px = max(2, int(min(w, h) * 0.35))
    lab_vec = sample_mean_lab_inside_circle(bgr, (cx, cy), radius_px)
    if lab_vec is None:
        return None
    return np.array([diameter_mm, lab_vec[0], lab_vec[1], lab_vec[2]], dtype=np.float32)


def load_dataset(manifest_path: Path, base_dir: Path):
    rows = load_manifest(manifest_path)
    if not rows:
        return None, None
    X_list = []
    y_list = []
    for rel_path, class_id, diameter_mm in rows:
        full_path = base_dir / rel_path
        if not full_path.is_file():
            continue
        img = cv2.imread(str(full_path))
        feat = extract_features(img, diameter_mm)
        if feat is not None:
            X_list.append(feat)
            y_list.append(class_id)
    if not X_list:
        return None, None
    X = np.array(X_list, dtype=np.float32)
    y = np.array(y_list, dtype=np.int32)
    return X, y


def load_dataset_from_training_data_2(base_dir: Path):
    labels_dir = base_dir / "labels"
    images_dir = base_dir / "images"
    if not labels_dir.is_dir() or not images_dir.is_dir():
        return None, None

    ratio_px_to_mm = load_ratio_px_to_mm()
    X_list = []
    y_list = []

    for label_path in sorted(labels_dir.glob("*.json")):
        with open(label_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        image_path = images_dir / data.get("imagePath", "")
        if not image_path.is_file():
            continue
        bgr = cv2.imread(str(image_path))
        if bgr is None:
            continue
        h, w = bgr.shape[:2]
        shapes = data.get("shapes", [])
        for shape in shapes:
            label_name = shape.get("label")
            center = shape.get("center")
            radius = shape.get("radius")
            if label_name not in LABEL_TO_CLASS_ID or not center or radius is None:
                continue
            if radius < 2:
                continue
            class_id = LABEL_TO_CLASS_ID[label_name]
            diameter_mm = (2 * radius) * ratio_px_to_mm
            cx, cy = int(center[0]), int(center[1])
            crop_side = max(50, min(2 * radius, min(h, w)))
            crop_side = crop_side + (1 if crop_side % 2 == 0 else 0)
            crop = extract_crop(bgr, cx, cy, crop_side, h, w)
            feat = extract_features(crop, diameter_mm)
            if feat is not None:
                X_list.append(feat)
                y_list.append(class_id)

    if not X_list:
        return None, None
    X = np.array(X_list, dtype=np.float32)
    y = np.array(y_list, dtype=np.int32)
    return X, y


def scale_like_cpp(X: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    n = X.shape[0]
    mean = np.mean(X, axis=0, keepdims=True).astype(np.float32)
    centered = X - mean
    var = np.mean(centered ** 2, axis=0, keepdims=True)
    scale = np.sqrt(var).astype(np.float32)
    scale = np.maximum(scale, 1e-9)
    X_scaled = (X - mean) / scale
    return X_scaled, mean, scale


def main() -> int:
    labels_dir = TRAINING_BASE / "labels"
    images_dir = TRAINING_BASE / "images"
    if labels_dir.is_dir() and images_dir.is_dir():
        X, y = load_dataset_from_training_data_2(TRAINING_BASE)
    elif MANIFEST_PATH.is_file():
        manifest = load_manifest(MANIFEST_PATH)
        if not manifest:
            print(f"No rows in {MANIFEST_PATH}")
            return 1
        X, y = load_dataset(MANIFEST_PATH, TRAINING_BASE)
    else:
        print(f"No training data found in {TRAINING_BASE}")
        print("Either provide images/ and labels/*.json (from train_acquisition), or manifest.csv")
        return 1

    if X is None or y is None:
        print("No valid samples loaded.")
        print("For training_data_2 ensure images/ and labels/*.json exist and shapes have label, center, radius.")
        return 1

    n = len(X)
    if n <= 10:
        print(f"Not enough valid samples ({n}). Need more than 10.")
        return 1

    print(f"Loaded {n} samples from {TRAINING_BASE}")

    X_scaled, mean, scale = scale_like_cpp(X)

    rng = np.random.default_rng(42)
    indices = np.arange(n)
    rng.shuffle(indices)
    n_test = max(1, n // 5)
    n_train = n - n_test
    train_idx = indices[:n_train]
    test_idx = indices[n_train:]

    X_train_part = X_scaled[train_idx]
    y_train_part = y[train_idx]
    X_test_part = X_scaled[test_idx]
    y_test_part = y[test_idx]

    def eval_model(model, X_te, y_te) -> float:
        correct = 0
        for i in range(len(y_te)):
            row = X_te[i : i + 1]
            pred = model.predict(row)
            if isinstance(pred, (tuple, list)) and len(pred) == 2:
                pred = int(pred[1].flat[0]) if pred[1].size else int(pred[0])
            else:
                pred = int(pred)
            if pred == y_te[i]:
                correct += 1
        return correct / len(y_te) if y_te.size else 0.0

    print(f"Testing models on {n_train} train / {n_test} test samples...")

    train_data_part = cv2.ml.TrainData_create(
        X_train_part,
        cv2.ml.ROW_SAMPLE,
        y_train_part.reshape(-1, 1).astype(np.int32),
    )

    svm = cv2.ml.SVM_create()
    svm.setType(cv2.ml.SVM_C_SVC)
    svm.setKernel(cv2.ml.SVM_RBF)
    svm.setGamma(0.5)
    svm.setC(1.0)
    svm.train(train_data_part)
    score_svm = eval_model(svm, X_test_part, y_test_part)
    print(f"  SVM: {score_svm:.4f} accuracy")

    knn = cv2.ml.KNearest_create()
    knn.setDefaultK(5)
    knn.train(train_data_part)
    score_knn = eval_model(knn, X_test_part, y_test_part)
    print(f"  KNN: {score_knn:.4f} accuracy")

    rtrees = cv2.ml.RTrees_create()
    rtrees.setTermCriteria((cv2.TERM_CRITERIA_MAX_ITER + cv2.TERM_CRITERIA_EPS, 100, 0.01))
    rtrees.train(train_data_part)
    score_rf = eval_model(rtrees, X_test_part, y_test_part)
    print(f"  RandomForest: {score_rf:.4f} accuracy")

    nb = cv2.ml.NormalBayesClassifier_create()
    nb.train(train_data_part)
    score_nb = eval_model(nb, X_test_part, y_test_part)
    print(f"  NaiveBayes: {score_nb:.4f} accuracy")

    scores = [score_svm, score_knn, score_rf, score_nb]
    best_idx = int(np.argmax(scores))
    best_score = scores[best_idx]
    print(f"Winner: {MODEL_TYPE_NAMES[best_idx]} ({best_score:.4f})")
    try:
        line = input("Save which model? [1=SVM 2=KNN 3=RandomForest 4=NaiveBayes] (Enter=winner): ").strip()
    except EOFError:
        line = ""
    save_idx = best_idx
    if line == "1":
        save_idx = 0
    elif line == "2":
        save_idx = 1
    elif line == "3":
        save_idx = 2
    elif line == "4":
        save_idx = 3

    full_train_data = cv2.ml.TrainData_create(
        X_scaled,
        cv2.ml.ROW_SAMPLE,
        y.reshape(-1, 1).astype(np.int32),
    )
    svm.train(full_train_data)
    knn.train(full_train_data)
    rtrees.train(full_train_data)
    nb.train(full_train_data)

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    model_paths = [MODELS_DIR / name for name in CLASSIFIER_MODEL_NAMES]
    svm.save(str(model_paths[0]))
    knn.save(str(model_paths[1]))
    rtrees.save(str(model_paths[2]))
    nb.save(str(model_paths[3]))

    scaler_full_path = MODELS_DIR / SCALER_PATH
    fs = cv2.FileStorage(str(scaler_full_path), cv2.FILE_STORAGE_WRITE)
    fs.write("mean", mean)
    fs.write("scale", scale)
    fs.write("model_type", MODEL_TYPE_NAMES[save_idx])
    fs.release()

    default_path = MODELS_DIR / DEFAULT_FILE
    with open(default_path, "w") as f:
        f.write(f"{save_idx}\n")

    print(f"Saved all 4 models. Active (default): {MODEL_TYPE_NAMES[save_idx]} ({model_paths[save_idx]}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
