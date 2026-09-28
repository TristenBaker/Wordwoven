"""Generates the small effect textures used by party animations.

Run from the project root:  python tools/art/generate_effect_art.py
"""

import os

from PIL import Image, ImageDraw

OUT_DIR = os.path.join("art", "party", "effects")


def spark() -> Image.Image:
    # White plus-shaped twinkle; particles tint it per effect.
    image = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    for x, y in ((2, 0), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
                 (2, 3), (2, 4)):
        image.putpixel((x, y), (255, 255, 255, 180))
    image.putpixel((2, 2), (255, 255, 255, 255))
    return image


def ring() -> Image.Image:
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((1, 1, 30, 30), outline=(255, 255, 255, 120), width=3)
    draw.ellipse((3, 3, 28, 28), outline=(255, 255, 255, 255), width=1)
    return image


def burst() -> Image.Image:
    # Eight-point impact star.
    image = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    c = 11.5
    points = []
    for index in range(16):
        import math
        angle = index * math.pi / 8
        radius = 11.5 if index % 2 == 0 else 4.5
        points.append((c + math.cos(angle) * radius,
                       c + math.sin(angle) * radius))
    draw.polygon(points, fill=(255, 236, 170, 255))
    draw.ellipse((8, 8, 15, 15), fill=(255, 255, 255, 255))
    return image


def shadow() -> Image.Image:
    image = Image.new("RGBA", (16, 5), (0, 0, 0, 0))
    ImageDraw.Draw(image).ellipse((0, 0, 15, 4), fill=(0, 0, 0, 110))
    return image


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in (("spark", spark), ("heal_ring", ring),
                        ("impact_burst", burst), ("shadow", shadow)):
        path = os.path.join(OUT_DIR, name + ".png")
        build().save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
