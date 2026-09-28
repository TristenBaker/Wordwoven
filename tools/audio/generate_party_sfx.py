"""Synthesises the placeholder party sound effects.

Run from the project root:  python tools/audio/generate_party_sfx.py

Writes 16-bit mono WAVs to assets/Audio/party/. Replace any file with
your own sound of the same name (or reassign the stream on the
PartySfx node in scenes/combat/party_stage.tscn) to swap it out.
"""

import os
import wave

import numpy as np

RATE = 44100
OUT_DIR = os.path.join("assets", "Audio", "party")
rng = np.random.default_rng(7)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def envelope(n: int, attack: float, decay_power: float = 2.0) -> np.ndarray:
    a = max(1, int(RATE * attack))
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    env[a:] = np.linspace(1, 0, n - a) ** decay_power
    return env


def lowpass(signal: np.ndarray, amount: float) -> np.ndarray:
    out = np.zeros_like(signal)
    acc = 0.0
    for i, value in enumerate(signal):
        acc += amount * (value - acc)
        out[i] = acc
    return out


def sweep(start: float, end: float, seconds: float) -> np.ndarray:
    freq = np.linspace(start, end, int(RATE * seconds))
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(RATE * seconds))


def step() -> np.ndarray:
    n = noise(0.05)
    return lowpass(n, 0.25) * envelope(len(n), 0.002, 4) * 1.4


def jump() -> np.ndarray:
    s = 0.16
    tone = sweep(220, 640, s) * 0.35
    air = lowpass(noise(s), 0.3) * 0.5
    return (tone + air) * envelope(int(RATE * s), 0.01, 1.5)


def slash() -> np.ndarray:
    s = 0.14
    n = noise(s)
    bright = n - lowpass(n, 0.2)
    ramp = np.linspace(0.2, 1.0, len(n))
    return bright * ramp * envelope(len(n), 0.06, 1.2) * 1.2


def impact() -> np.ndarray:
    s = 0.22
    thump = sweep(140, 45, s) * envelope(int(RATE * s), 0.002, 3)
    crack = lowpass(noise(s), 0.5) * envelope(int(RATE * s), 0.001, 8)
    return thump * 0.9 + crack * 0.7


def heal() -> np.ndarray:
    s = 0.55
    t = t_axis(s)
    out = np.zeros_like(t)
    # Rising major arpeggio with a shimmering tail.
    for index, freq in enumerate((523.25, 659.25, 783.99, 1046.5)):
        start = int(index * 0.06 * RATE)
        seg = t[: len(t) - start]
        tone = np.sin(2 * np.pi * freq * seg) \
            + 0.3 * np.sin(2 * np.pi * freq * 2 * seg)
        tone *= envelope(len(seg), 0.005, 2.5)
        out[start:] += tone * 0.25
    shimmer = np.sin(2 * np.pi * 2093 * t) * np.sin(2 * np.pi * 9 * t)
    return out + shimmer * envelope(len(t), 0.2, 2) * 0.08


def coin() -> np.ndarray:
    s = 0.3
    t = t_axis(s)
    out = np.zeros_like(t)
    for delay, freq in ((0.0, 1318.5), (0.07, 1975.5)):
        start = int(delay * RATE)
        seg = t[: len(t) - start]
        tone = np.sign(np.sin(2 * np.pi * freq * seg)) * 0.25
        out[start:] += tone * envelope(len(seg), 0.002, 3)
    return out * 0.8


def dash() -> np.ndarray:
    s = 0.2
    n = lowpass(noise(s), 0.45)
    ramp = np.sin(np.linspace(0, np.pi, len(n)))
    return n * ramp * 1.3


def enemy_death() -> np.ndarray:
    s = 0.8
    t = t_axis(s)
    growl = sweep(180, 40, s) * (1 + 0.5 * np.sin(2 * np.pi * 30 * t))
    rumble = lowpass(noise(s), 0.08) * 2.0
    return (growl * 0.5 + rumble * 0.6) * envelope(len(t), 0.01, 1.5)


def write(name: str, samples: np.ndarray) -> None:
    peak = np.max(np.abs(samples)) or 1.0
    data = (samples / peak * 0.85 * 32767).astype(np.int16)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    print("wrote", path)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in (("step", step), ("jump", jump), ("slash", slash),
                        ("impact", impact), ("heal", heal), ("coin", coin),
                        ("dash", dash), ("enemy_death", enemy_death)):
        write(name, build())


if __name__ == "__main__":
    main()
