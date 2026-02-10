import json
import torch
import torch.nn as nn
import numpy as np
from pathlib import Path
from PIL import Image
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from torchvision.models import resnet18
from torch.fx import symbolic_trace
from torch.ao.quantization import get_default_qconfig
from torch.ao.quantization.quantize_fx import prepare_fx, convert_fx

REPO_ROOT = Path(__file__).resolve().parent
MODELS_DIR = REPO_ROOT / "data" / "models"
DATA_ROOT = REPO_ROOT / "data" / "training_data_2"

NUM_CLASSES = 6
CROP_SIZE = 150
LABEL_TO_ID = {"20cent": 0, "10cent": 1, "1euro": 2, "1cent": 3, "2cent": 4, "5cent": 5}


def extract_crop(img_array, cx, cy, crop_size, h, w):
    """Extract a crop_size x crop_size region centered at (cx, cy). Pad with zeros if out of bounds."""
    half = crop_size // 2
    x1, y1 = cx - half, cy - half
    x2, y2 = cx + half, cy + half
    src_x1, src_y1 = max(0, x1), max(0, y1)
    src_x2, src_y2 = min(w, x2), min(h, y2)
    dst_x1, dst_y1 = src_x1 - x1, src_y1 - y1
    crop_h, crop_w = src_y2 - src_y1, src_x2 - src_x1
    canvas = np.zeros((crop_size, crop_size, 3), dtype=np.uint8)
    if crop_h > 0 and crop_w > 0:
        canvas[dst_y1 : dst_y1 + crop_h, dst_x1 : dst_x1 + crop_w] = img_array[
            src_y1:src_y2, src_x1:src_x2
        ]
    return Image.fromarray(canvas, mode="RGB")


class CoinDatasetFromCenters(Dataset):
    """Build dataset from training_data_2: full images + JSON labels; each sample = 150x150 crop at label center."""

    def __init__(self, root, label_to_id, crop_size=150, transform=None):
        self.root = Path(root)
        self.transform = transform
        self.crop_size = crop_size
        self.label_to_id = label_to_id
        self.samples = []
        images_dir = self.root / "images"
        labels_dir = self.root / "labels"
        if not images_dir.is_dir() or not labels_dir.is_dir():
            return
        for label_path in sorted(labels_dir.glob("*.json")):
            with open(label_path, "r") as f:
                data = json.load(f)
            image_path = images_dir / data["imagePath"]
            if not image_path.exists():
                continue
            for shape in data.get("shapes", []):
                label_name = shape.get("label")
                center = shape.get("center")
                if label_name not in self.label_to_id or not center:
                    continue
                cx, cy = int(center[0]), int(center[1])
                self.samples.append((str(image_path), cx, cy, self.label_to_id[label_name]))

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        image_path, cx, cy, label = self.samples[idx]
        img = Image.open(image_path).convert("RGB")
        arr = np.array(img)
        h, w = arr.shape[:2]
        crop = extract_crop(arr, cx, cy, self.crop_size, h, w)
        if self.transform:
            crop = self.transform(crop)
        return crop, label


class SmallCNN(nn.Module):
    def __init__(self, num_classes=6):
        super().__init__()
        self.features = nn.Sequential(

            nn.Conv2d(3, 32, kernel_size=7, padding=2),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(4),

            nn.Conv2d(32, 64, kernel_size=5, padding=2),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(4),

            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),

            nn.AdaptiveAvgPool2d(1)
        )

        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Linear(128, 64),
            nn.ReLU(inplace=True),
            nn.Dropout(0.5),
            nn.Linear(64, num_classes),
        )

    def forward(self, x):
        return self.classifier(self.features(x))


CALIBRATION_TRANSFORM = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])


def _get_calibration_loader():
    """Build DataLoader over data/training_data_2 for FX calibration. Returns None if data dir missing."""
    if not DATA_ROOT.exists():
        return None
    cal_ds = CoinDatasetFromCenters(DATA_ROOT, LABEL_TO_ID, crop_size=CROP_SIZE, transform=CALIBRATION_TRANSFORM)
    if len(cal_ds) == 0:
        return None
    return DataLoader(cal_ds, batch_size=32, shuffle=False, num_workers=0)


def _quantize_fx(model, calibration_loader, example_input, backend="fbgemm", max_batches=None):
    """Run symbolic_trace -> prepare_fx -> calibration -> convert_fx. Returns quantized model."""
    graph_module = symbolic_trace(model)
    qconfig = get_default_qconfig(backend)
    qconfig_dict = {"": qconfig}
    prepared = prepare_fx(graph_module, qconfig_dict)
    prepared.eval()
    with torch.no_grad():
        for i, (batch, _) in enumerate(calibration_loader):
            if max_batches is not None and i >= max_batches:
                break
            prepared(batch)
    return convert_fx(prepared)


def main():
    device = torch.device("cpu")
    example = torch.rand(1, 3, CROP_SIZE, CROP_SIZE, device=device)

    load_kw = {"map_location": device}
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    ckpt = torch.load(str(MODELS_DIR / "coin_cnn.pt"), **load_kw)
    model_cnn = SmallCNN(num_classes=NUM_CLASSES)
    model_cnn.load_state_dict(ckpt["model_state"], strict=True)
    model_cnn.eval()
    traced_cnn = torch.jit.trace(model_cnn, example)
    traced_cnn.save(str(MODELS_DIR / "coin_cnn_traced.pt"))
    print("Saved", MODELS_DIR / "coin_cnn_traced.pt")

    ckpt = torch.load(str(MODELS_DIR / "coin_resnet18.pt"), **load_kw)
    model_resnet = resnet18(weights=None)
    model_resnet.fc = nn.Linear(model_resnet.fc.in_features, NUM_CLASSES)
    model_resnet.load_state_dict(ckpt["model_state"], strict=True)
    model_resnet.eval()
    traced_resnet = torch.jit.trace(model_resnet, example)
    traced_resnet.save(str(MODELS_DIR / "coin_resnet18_traced.pt"))
    print("Saved", MODELS_DIR / "coin_resnet18_traced.pt")

    calibration_loader = _get_calibration_loader()
    if calibration_loader is None:
        print("Skipping quantization: data/training_data_2 not found or empty.")
        return

    ckpt = torch.load(str(MODELS_DIR / "coin_cnn.pt"), **load_kw)
    model_cnn_q = SmallCNN(num_classes=NUM_CLASSES)
    model_cnn_q.load_state_dict(ckpt["model_state"], strict=True)
    model_cnn_q.eval()
    quantized_cnn = _quantize_fx(model_cnn_q, calibration_loader, example, max_batches=50)
    traced_cnn_q = torch.jit.trace(quantized_cnn, example)
    traced_cnn_q.save(str(MODELS_DIR / "coin_cnn_quantized.pt"))
    print("Saved", MODELS_DIR / "coin_cnn_quantized.pt")

    ckpt = torch.load(str(MODELS_DIR / "coin_resnet18.pt"), **load_kw)
    model_resnet_q = resnet18(weights=None)
    model_resnet_q.fc = nn.Linear(model_resnet_q.fc.in_features, NUM_CLASSES)
    model_resnet_q.load_state_dict(ckpt["model_state"], strict=True)
    model_resnet_q.eval()
    quantized_resnet = _quantize_fx(model_resnet_q, calibration_loader, example, max_batches=50)
    traced_resnet_q = torch.jit.trace(quantized_resnet, example)
    traced_resnet_q.save(str(MODELS_DIR / "coin_resnet18_quantized.pt"))
    print("Saved", MODELS_DIR / "coin_resnet18_quantized.pt")


if __name__ == "__main__":
    main()
