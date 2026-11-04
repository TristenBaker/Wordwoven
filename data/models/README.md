# Offline forge handwriting model

`forge_letters.json` contains a 784 → 96 ReLU → 26 fully connected neural
network trained for single handwritten A–Z letters. It runs locally in
`ForgeLetterRecognizer`, using GDScript and the bundled weights. There is no
network call, Python process, external runtime, or drawing upload at play time.

Training data: EMNIST Letters, 124,800 training and 20,800 test samples.
Source mirror: https://huggingface.co/datasets/tanganke/emnist_letters
Original dataset and attribution: https://www.nist.gov/itl/products-and-services/emnist-dataset
Paper: https://arxiv.org/abs/1702.05373

Training: fixed seed 721, Adam at 0.001, batches of 256, 20 epochs. Final
held-out test accuracy: 87.99%. This is handwriting dataset accuracy, not a
guarantee for mouse drawings. Ambiguous letters and unusual drawings will be
misread; accepting the interpretation is part of the forge mechanic.

Training preprocessing transposes the stored EMNIST axes to upright, removes
pixels below 25/255, tightly crops ink, fits the longest side to 20 pixels,
and centers the result on a 28×28 black canvas with white ink. The drawing
board rasterizes separate pointer strokes into this same centered format.
The model accepts upper- and lowercase examples but emits a single A–Z class.

`forge_fixtures.json` holds one correctly classified held-out image per letter
for verifying Godot/PyTorch inference parity. It is a smoke test, not the test
set used for the accuracy figure above.

To reproduce training (Python is needed only for development):

1. Install numpy, Pillow, torch, and pyarrow in your training environment.
2. Download `emnist-letters/train-00000-of-00001.parquet` and
   `emnist-letters/test-00000-of-00001.parquet` from the source mirror into
   `.tmp/handwriting/train.parquet` and `.tmp/handwriting/test.parquet`.
3. From the repository root, run `python tools/train_forge_recognizer.py`.
4. Run `tools/handwriting_forge_test.tscn` with Godot to verify inference,
   stroke normalization, recipe validation, sacrifice, reward, and animation.

The cache and training dependencies in `.tmp/handwriting/` are ignored by Git.
Ship `forge_letters.json` with the game alongside the existing JSON catalogs.
