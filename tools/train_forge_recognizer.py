"""Train the bundled offline EMNIST recognizer. Training-only dependencies:
numpy, Pillow, torch, pyarrow. See data/models/README.md for provenance.
"""
import argparse
import io
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image
import torch

sys.path.insert(0, str(Path('.tmp/handwriting/deps').resolve()))
import pyarrow.parquet as pq


def normalize(image):
    pixels = np.asarray(image.convert('L')).copy()
    pixels[pixels < 25] = 0
    image = Image.fromarray(pixels)
    box = image.getbbox()
    if box is None:
        return np.zeros(784, np.float32)
    image = image.crop(box)
    w, h = image.size
    factor = 20 / max(w, h)
    image = image.resize((max(1, round(w * factor)), max(1, round(h * factor))), Image.Resampling.BILINEAR)
    canvas = Image.new('L', (28, 28))
    canvas.paste(image, ((28 - image.width) // 2, (28 - image.height) // 2))
    return np.asarray(canvas, dtype=np.float32).reshape(-1) / 255


def load(path):
    rows = pq.read_table(path).to_pylist()
    images = []
    labels = []
    for row in rows:
        image = Image.open(io.BytesIO(row['image']['bytes']))
        # EMNIST's stored axes are transposed relative to upright handwriting.
        image = image.transpose(Image.Transpose.TRANSPOSE)
        images.append(normalize(image))
        labels.append(row['label'])
    return torch.from_numpy(np.stack(images)), torch.tensor(labels)


def main():
    torch.manual_seed(721)
    torch.set_num_threads(4)
    train_x, train_y = load('.tmp/handwriting/train.parquet')
    test_x, test_y = load('.tmp/handwriting/test.parquet')
    print('Training samples:', len(train_x), 'labels:', train_y.min().item(), train_y.max().item(), flush=True)
    net = torch.nn.Sequential(torch.nn.Linear(784, 96), torch.nn.ReLU(), torch.nn.Linear(96, 26))
    optimizer = torch.optim.Adam(net.parameters(), lr=0.001)
    for epoch in range(20):
        order = torch.randperm(len(train_x))
        net.train()
        for batch in order.split(256):
            optimizer.zero_grad()
            loss = torch.nn.functional.cross_entropy(net(train_x[batch]), train_y[batch])
            loss.backward()
            optimizer.step()
        net.eval()
        with torch.no_grad():
            accuracy = (net(test_x).argmax(1) == test_y).float().mean().item()
        print(f'Epoch {epoch + 1}: held-out accuracy {accuracy:.4f}', flush=True)
    model = {'format': 1, 'labels': 'abcdefghijklmnopqrstuvwxyz', 'input_size': 28,
             'hidden_size': 96, 'test_accuracy': accuracy, 'test_samples': len(test_y),
             'weights_1': net[0].weight.detach().flatten().tolist(), 'bias_1': net[0].bias.detach().tolist(),
             'weights_2': net[2].weight.detach().flatten().tolist(), 'bias_2': net[2].bias.detach().tolist()}
    Path('data/models/forge_letters.json').write_text(json.dumps(model, separators=(',', ':')))
    # Upright, held-out inputs also exercise Godot's inference implementation.
    fixtures = []
    for label in range(26):
        candidates = (test_y == label).nonzero().flatten()
        with torch.no_grad():
            predictions = net(test_x[candidates]).argmax(1)
        correct = candidates[(predictions == label).nonzero().flatten()[0]]
        fixtures.append({'letter': chr(97 + label), 'pixels': test_x[correct].tolist()})
    Path('data/models/forge_fixtures.json').write_text(json.dumps(fixtures, separators=(',', ':')))


if __name__ == '__main__':
    main()
