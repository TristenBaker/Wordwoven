"""Generates the detailed tavern portraits for each party class.

Run from the project root:  python tools/art/generate_portrait_art.py

Writes art/party/portraits/<class>_1.png (64x96). The "_1" suffix is
the level tier: future art for higher levels can be added as
<class>_2.png, <class>_3.png... and assigned in the CharacterPortrait
scene's per-class texture arrays.
"""

import os

from pixel_canvas import Canvas, Ramp, rgb

WIDTH = 64
HEIGHT = 96
OUT_DIR = os.path.join("art", "party", "portraits")

SKIN = Ramp("#c07a58", "#efb68c", "#ffd8b6")
EYE = "#20121f"
BOOT = Ramp("#2e1d14", "#553522", "#7a5234")
STEEL = Ramp("#4f5b6b", "#94a3b4", "#e2ebf3")
DARK_STEEL = Ramp("#39404c", "#646f7e", "#8e9aa8")
GOLD = Ramp("#8f5b10", "#dca226", "#ffe28a")
WOOD = Ramp("#472a15", "#77502e", "#a47648")
LEATHER = Ramp("#3a2419", "#5e3c2a", "#86593f")


def eyes(c: Canvas, x: int, y: int, iris: str) -> None:
    # Two 2x3 eyes with an iris and a highlight.
    for ex in (x, x + 7):
        c.rect((ex, y, ex + 2, y + 3), Ramp("#ffffff", "#ffffff",
                                            "#ffffff"), bevel=False)
        c.rect((ex + 1, y, ex + 2, y + 3), Ramp(iris, iris, iris),
               bevel=False)
        c.dot(ex + 2, y + 3, EYE)
        c.dot(ex + 1, y, "#ffffff")
        c.line([(ex - 1, y - 2), (ex + 3, y - 2)], "#4a2c20")


def ground_shadow(c: Canvas) -> None:
    shadow = (20, 12, 10, 90)
    from PIL import ImageDraw
    ImageDraw.Draw(c.image).ellipse((10, 88, 54, 95), fill=shadow)


# --- warrior --------------------------------------------------------

def warrior() -> Canvas:
    c = Canvas(WIDTH, HEIGHT)
    ground_shadow(c)
    cape = Ramp("#4e1216", "#7d2024", "#a3363a")
    tabard = Ramp("#6e1c20", "#a8343a", "#d65e58")
    # Cape behind the body.
    c.poly([(20, 34), (44, 34), (50, 86), (14, 86)], cape)
    # Legs: greaves over dark trousers, then boots.
    for x in (22, 34):
        c.rect((x, 62, x + 7, 80), DARK_STEEL)
        c.rect((x + 1, 68, x + 6, 70), STEEL)
        c.rect((x - 1, 80, x + 8, 89), BOOT)
        c.rect((x - 1, 87, x + 9, 89), LEATHER)
    # Breastplate and tabard with a gold crest.
    c.poly([(19, 36), (45, 36), (43, 62), (21, 62)], STEEL)
    c.rect((26, 40, 38, 74), tabard)
    c.poly([(26, 74), (38, 74), (32, 80)], tabard)
    c.poly([(32, 46), (36, 51), (32, 58), (28, 51)], GOLD)
    c.dot(32, 51, "#fff4c4")
    c.rect((21, 60, 43, 63), LEATHER)
    c.rect((30, 59, 34, 64), GOLD)
    # Shield on the back arm.
    c.poly([(3, 42), (21, 42), (21, 60), (12, 76), (3, 60)], STEEL)
    c.poly([(5, 44), (19, 44), (19, 59), (12, 72), (5, 59)], tabard)
    c.rect((11, 46, 13, 68), GOLD)
    c.rect((6, 53, 18, 55), GOLD)
    c.dots([(5, 44), (19, 44), (5, 58), (19, 58), (12, 72)], "#ffe28a")
    # Pauldrons with rivets.
    c.ellipse((13, 32, 27, 44), STEEL)
    c.ellipse((37, 32, 51, 44), STEEL)
    c.dots([(17, 36), (22, 35), (42, 35), (47, 36)], "#39404c")
    # Front arm resting a sword on the shoulder.
    c.rect((43, 42, 50, 56), tabard)
    c.rect((42, 52, 51, 58), DARK_STEEL)
    c.line([(47, 56), (61, 16)], "#e2ebf3", 3)
    c.line([(48, 56), (62, 17)], "#94a3b4", 1)
    c.dots([(60, 18), (61, 17), (62, 16)], "#ffffff")
    c.rect((42, 55, 52, 57), GOLD)
    c.rect((45, 57, 49, 62), LEATHER)
    c.ellipse((45, 61, 49, 65), GOLD)
    c.ellipse((44, 53, 50, 58), SKIN)
    # Head: helmet with an open face and a flowing plume.
    plume = Ramp("#8a161e", "#d2303a", "#ff7a6a")
    c.poly([(30, 4), (38, 2), (26, 12), (12, 24), (10, 18), (20, 8)],
           plume)
    c.ellipse((21, 10, 43, 36), SKIN)
    c.shape(lambda d: d.chord((19, 7, 45, 40), 180, 360, fill=255),
            STEEL)
    c.rect((19, 22, 24, 33), STEEL)
    c.rect((40, 22, 45, 33), STEEL)
    c.rect((31, 8, 33, 22), Ramp("#94a3b4", "#e2ebf3", "#ffffff"),
           bevel=False)
    c.rect((20, 21, 44, 22), GOLD)
    eyes(c, 25, 25, "#3b6fb5")
    c.line([(31, 32), (33, 32)], "#a4583f")
    c.dots([(24, 30), (39, 30)], "#f59a8a")
    c.outline()
    return c


# --- healer ---------------------------------------------------------

def healer() -> Canvas:
    c = Canvas(WIDTH, HEIGHT)
    ground_shadow(c)
    robe = Ramp("#1c5236", "#2f7d53", "#5db67f")
    trim = Ramp("#b3a270", "#eee2bb", "#fffbea")
    orb = Ramp("#46b36a", "#a6f0b4", "#fbfff0")
    hair = Ramp("#b07a1c", "#e8b640", "#ffe590")
    # Glow halo around the staff orb.
    from PIL import ImageDraw
    ImageDraw.Draw(c.image).ellipse((42, 0, 62, 20),
                                    fill=(190, 255, 205, 70))
    # Staff with a leaf wrap and the glowing orb.
    c.rect((50, 10, 53, 90), WOOD)
    c.poly([(47, 6), (51, 2), (55, 2), (58, 6), (55, 8), (48, 8)], WOOD)
    c.ellipse((46, 3, 57, 14), orb)
    c.dots([(49, 6), (50, 5)], "#ffffff")
    for y in (20, 26):
        c.poly([(53, y), (58, y - 3), (57, y + 1)],
               Ramp("#2f7d53", "#5db67f", "#9ce0b0"))
    # Robe falling to the ground with trim and a sash.
    c.poly([(21, 36), (43, 36), (50, 88), (14, 88)], robe)
    c.rect((14, 84, 50, 88), trim)
    c.rect((30, 40, 34, 84), trim)
    c.rect((20, 56, 44, 60), GOLD)
    c.poly([(36, 60), (40, 60), (42, 72), (37, 70)], GOLD)
    c.ellipse((18, 60, 25, 68), LEATHER)
    c.rect((20, 60, 23, 61), GOLD)
    # Satchel strap across the chest.
    c.line([(22, 38), (40, 56)], "#5e3c2a", 2)
    # Mantle over the shoulders.
    c.poly([(16, 34), (48, 34), (44, 46), (20, 46)], robe)
    c.rect((17, 44, 47, 46), trim)
    # Sleeves and hands on the staff.
    c.poly([(42, 38), (48, 44), (50, 56), (44, 56)], robe)
    c.rect((43, 54, 50, 56), trim)
    c.ellipse((46, 52, 54, 59), SKIN)
    c.poly([(22, 38), (16, 48), (18, 60), (24, 56)], robe)
    # Hood framing the face, with golden braids.
    c.ellipse((16, 6, 48, 40), robe)
    c.poly([(18, 14), (8, 32), (20, 30)], robe)
    c.ellipse((22, 12, 42, 36), SKIN)
    c.poly([(22, 14), (42, 14), (40, 20), (32, 17), (24, 21)], hair)
    c.rect((20, 24, 23, 44), hair)
    c.rect((41, 24, 44, 44), hair)
    c.dots([(21, 30), (21, 36), (42, 30), (42, 36)], "#b07a1c")
    c.shape(lambda d: d.arc((20, 9, 44, 39), 190, 350, fill=255), trim,
            bevel=False)
    eyes(c, 26, 23, "#3a8c5a")
    c.line([(31, 31), (34, 31)], "#b25b48")
    c.dots([(25, 28), (39, 28)], "#f59a8a")
    c.outline()
    # Loose sparkles drift outside the outline.
    for x, y in ((6, 12), (12, 4), (58, 28), (4, 40), (60, 44)):
        c.dots([(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)],
               "#c8ffd8")
        c.dot(x, y, "#ffffff")
    return c


# --- rogue ----------------------------------------------------------

def rogue() -> Canvas:
    c = Canvas(WIDTH, HEIGHT)
    ground_shadow(c)
    cloak = Ramp("#1c1729", "#342c4a", "#564c74")
    cloth = Ramp("#2a2238", "#40375a", "#62587e")
    scarf = GOLD
    # Cloak flaring out behind.
    c.poly([(18, 34), (46, 34), (54, 84), (40, 80), (30, 86), (20, 80),
            (8, 84)], cloak)
    # Scarf tails whipping to the left.
    c.poly([(22, 36), (4, 30), (0, 38), (6, 40), (2, 46), (22, 42)], scarf)
    # Legs in wrapped trousers and tall boots.
    for x in (23, 34):
        c.rect((x, 62, x + 7, 76), cloth)
        c.line([(x, 66), (x + 7, 68)], "#1c1729")
        c.line([(x, 71), (x + 7, 73)], "#1c1729")
        c.rect((x - 1, 76, x + 8, 89), LEATHER)
        c.rect((x - 1, 76, x + 8, 78), Ramp("#5e3c2a", "#86593f",
                                           "#a8744f"))
    # Leather jerkin with crossed straps and a coin pouch.
    c.poly([(20, 36), (44, 36), (43, 64), (21, 64)], LEATHER)
    c.line([(21, 38), (43, 60)], "#2e1d14", 2)
    c.line([(43, 38), (21, 60)], "#2e1d14", 2)
    c.ellipse((29, 45, 35, 51), GOLD)
    c.rect((20, 60, 44, 63), cloth)
    c.ellipse((36, 62, 44, 70), LEATHER)
    c.rect((38, 62, 42, 63), GOLD)
    c.dots([(40, 66), (41, 67)], "#ffe28a")
    # Back arm with a reverse-grip dagger.
    c.rect((14, 40, 20, 56), cloth)
    c.ellipse((13, 54, 20, 60), SKIN)
    c.line([(15, 60), (11, 74)], "#e2ebf3", 2)
    c.dot(11, 74, "#ffffff")
    c.rect((13, 58, 18, 59), GOLD, bevel=False)
    # Front arm with a forward dagger.
    c.rect((44, 40, 50, 52), cloth)
    c.ellipse((45, 50, 52, 56), SKIN)
    c.line([(50, 52), (60, 44)], "#e2ebf3", 2)
    c.line([(51, 53), (60, 45)], "#94a3b4", 1)
    c.dot(61, 43, "#ffffff")
    c.rect((47, 51, 50, 55), GOLD, bevel=False)
    # Scarf wrapped at the neck.
    c.rect((20, 32, 44, 38), scarf)
    c.line([(22, 35), (42, 35)], "#8f5b10")
    # Hood, shadowed face, mask and bright eyes.
    c.ellipse((17, 4, 47, 38), cloak)
    c.poly([(22, 8), (12, 0), (18, 16)], cloak)
    c.ellipse((23, 13, 42, 34), SKIN)
    c.shape(lambda d: d.chord((22, 10, 43, 30), 180, 360, fill=255),
            Ramp("#231d33", "#231d33", "#342c4a"), bevel=False)
    c.rect((23, 27, 42, 34), Ramp("#15101f", "#241c30", "#3a3050"))
    c.line([(24, 29), (41, 29)], "#3a3050")
    eyes(c, 26, 21, "#d4a018")
    c.outline()
    return c


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in (("warrior", warrior), ("healer", healer),
                        ("rogue", rogue)):
        path = os.path.join(OUT_DIR, name + "_1.png")
        build().image.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
