import torch
import torch.nn as nn
from pathlib import Path
from torchvision.models import resnet18

REPO_ROOT = Path(__file__).resolve().parent
MODELS_DIR = REPO_ROOT / "data" / "models"

NUM_CLASSES = 6
CROP_SIZE = 150


import torch.nn as nn

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


if __name__ == "__main__":
    main()
