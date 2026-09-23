"""Generates the chibi party sprite sheets used on the combat stage.

Run from the project root:  python tools/art/generate_chibi_art.py

Each class gets one horizontal strip of 32x32 frames in
art/party/chibi/<class>.png. FRAME_ORDER lists the frame names in strip
order; tools/art/write_sprite_frames.py turns that into SpriteFrames.
"""

import os

from PIL import Image

from pixel_canvas import Canvas, Ramp

FRAME = 32
OUT_DIR = os.path.join("art", "party", "chibi")

SKIN = Ramp("#c9825f", "#f2b98f", "#ffd9b8")
EYE = "#241424"
BOOT = Ramp("#3a2418", "#5c3a24", "#7a5234")
STEEL = Ramp("#5d6a7a", "#9aa8b8", "#dfe8f0")
GOLD = Ramp("#9a6512", "#e0a526", "#ffe07a")
WOOD = Ramp("#4f3019", "#7d5230", "#a8784a")

WARRIOR_CLOTH = Ramp("#6e1f22", "#a8363a", "#d8605a")
PLUME = Ramp("#8f1b22", "#d8343b", "#ff7a6a")
HEALER_CLOTH = Ramp("#1f5a3b", "#34865a", "#62bd84")
HEALER_TRIM = Ramp("#b8a878", "#efe4c0", "#fffbea")
ROGUE_CLOTH = Ramp("#231d33", "#3b3354", "#5f5680")
ROGUE_LEATHER = Ramp("#2d2120", "#4a3631", "#6b5048")

FRAME_ORDER = {
    "warrior": [
        "idle_0", "idle_1", "walk_0", "walk_1", "walk_2", "walk_3",
        "crouch", "leap", "slash",
    ],
    "healer": [
        "idle_0", "idle_1", "walk_0", "walk_1", "walk_2", "walk_3",
        "cast_0", "cast_1", "cast_2",
    ],
    "rogue": [
        "idle_0", "idle_1", "walk_0", "walk_1", "walk_2", "walk_3",
        "run_0", "run_1", "run_2", "run_3", "grab",
    ],
}

# (back leg dx, back leg lift, front leg dx, front leg lift, body bob)
WALK_LEGS = [
    (-1, 0, 1, 0, 0),
    (0, 1, 0, 0, -1),
    (1, 0, -1, 0, 0),
    (0, 0, 0, 1, -1),
]
RUN_LEGS = [
    (-2, 0, 2, 1, 0),
    (0, 2, 0, 0, -1),
    (2, 1, -2, 0, 0),
    (0, 0, 0, 2, -1),
]
IDLE_LEGS = [(0, 0, 0, 0, 0), (0, 0, 0, 0, 0)]


class Pose:
    def __init__(self, legs=(0, 0, 0, 0, 0), breathe: int = 0,
                 lean: int = 0, crouch: int = 0, tuck: bool = False,
                 arm: str = "down", flutter: int = 0, glow: int = 0):
        self.back_dx, self.back_lift, self.front_dx, self.front_lift, \
            self.bob = legs
        self.breathe = breathe
        self.lean = lean
        self.crouch = crouch
        self.tuck = tuck
        self.arm = arm
        self.flutter = flutter
        self.glow = glow


# --- shared body parts ----------------------------------------------

def body_origin(pose: Pose) -> tuple:
    # Character art is laid out for a 24px body; x 4 / y 7 centres it.
    return 4, 7 + pose.bob + pose.crouch


def draw_legs(c: Canvas, pose: Pose, pants: Ramp) -> None:
    ox, oy = 4, 7
    if pose.tuck:
        c.rect((ox + 8, oy + 16 + pose.bob, ox + 14, oy + 18 + pose.bob),
               pants)
        c.rect((ox + 9, oy + 18 + pose.bob, ox + 15, oy + 19 + pose.bob),
               BOOT)
        return
    for dx, lift, x in ((pose.back_dx, pose.back_lift, 8),
                        (pose.front_dx, pose.front_lift, 12)):
        top = oy + 17 + pose.crouch
        bottom = oy + 21 - lift
        c.rect((ox + x + dx, top, ox + x + dx + 2, bottom - 1), pants)
        c.rect((ox + x + dx, bottom - 1, ox + x + dx + 3, bottom), BOOT)


def draw_face(c: Canvas, x: int, y: int, masked: bool = False) -> None:
    # Big chibi eyes with a highlight pixel, looking right.
    for ex in (x, x + 3):
        c.dots([(ex, y), (ex, y + 1)], EYE)
    c.dot(x + 1, y, "#ffffff")
    c.dot(x + 4, y, "#ffffff")
    if not masked:
        c.dot(x + 2, y + 3, "#b86a4e")
        c.dot(x - 1, y + 2, "#f59a8a")
        c.dot(x + 4, y + 2, "#f59a8a")


# --- warrior --------------------------------------------------------

def draw_sword(c: Canvas, hand: tuple, tip: tuple) -> None:
    hx, hy = hand
    c.line([hand, tip], "#dfe8f0", 2)
    c.line([hand, tip], "#9aa8b8", 1)
    c.dot(tip[0], tip[1], "#ffffff")
    c.rect((hx - 1, hy - 1, hx + 1, hy + 1), GOLD, bevel=False)


def draw_warrior(pose: Pose) -> Canvas:
    c = Canvas(FRAME, FRAME)
    ox, oy = body_origin(pose)
    lx = ox + pose.lean
    by = oy + pose.breathe
    if pose.arm == "raise":
        # Arm and sword sit behind the head while winding up.
        draw_sword(c, (lx + 7, by + 6), (lx + 1, by - 3))
        c.rect((lx + 6, by + 6, lx + 8, by + 12), WARRIOR_CLOTH)
    draw_legs(c, pose, Ramp("#3b3040", "#584a5e", "#7a6a80"))
    # Tunic, belt, and pauldron.
    c.rect((ox + 7, by + 13, ox + 15, by + 18), WARRIOR_CLOTH)
    c.rect((ox + 7, by + 16, ox + 15, by + 16), BOOT, bevel=False)
    c.dot(ox + 12, by + 16, "#ffe07a")
    c.ellipse((ox + 6, by + 12, ox + 10, by + 15), STEEL)
    # Head, helmet, plume.
    c.ellipse((lx + 5, by + 2, lx + 17, by + 14), SKIN)
    c.shape(lambda d: d.chord((lx + 4, by + 1, lx + 18, by + 17),
                              180, 360, fill=255), STEEL)
    c.rect((lx + 4, by + 8, lx + 8, by + 12), STEEL)
    c.line([(lx + 9, by + 3), (lx + 9, by + 8)], "#dfe8f0")
    c.ellipse((lx + 5, by - 1, lx + 11, by + 4), PLUME)
    c.ellipse((lx + 2, by + 1, lx + 7, by + 5), PLUME)
    draw_face(c, lx + 12, by + 9)
    # Front arm and sword.
    if pose.arm == "down":
        c.rect((ox + 14, by + 13, ox + 16, by + 16), WARRIOR_CLOTH)
        draw_sword(c, (ox + 16, by + 16), (ox + 22, by + 10))
    elif pose.arm == "slash":
        c.rect((ox + 15, by + 13, ox + 18, by + 15), WARRIOR_CLOTH)
        draw_sword(c, (ox + 19, by + 15), (ox + 26, by + 21))
        # Motion arc in front of the swing.
        arc = [(24, 6), (26, 8), (27, 10), (28, 13), (28, 16), (27, 19)]
        c.dots([(x + ox - 4, y + by - 7) for x, y in arc], "#ffffff")
        arc2 = [(22, 6), (24, 8), (25, 11), (26, 14)]
        c.dots([(x + ox - 4, y + by - 7) for x, y in arc2], "#c9e6ff")
    c.outline()
    return c


# --- healer ---------------------------------------------------------

def draw_healer(pose: Pose) -> Canvas:
    c = Canvas(FRAME, FRAME)
    ox, oy = body_origin(pose)
    by = oy + pose.breathe
    raise_y = {0: 0, 1: -3, 2: -5}.get(pose.glow, 0)
    # Staff behind the body, raised while casting.
    sx = ox + 19
    c.rect((sx, by + 4 + raise_y, sx + 1, oy + 21 + raise_y // 2), WOOD)
    orb_y = by + 1 + raise_y
    if pose.glow >= 2:
        c.ellipse((sx - 4, orb_y - 4, sx + 5, orb_y + 5),
                  Ramp("#7ee0a0", "#b8ffd0", "#f4fff4"), bevel=False)
    c.ellipse((sx - 2, orb_y - 2, sx + 3, orb_y + 3),
              Ramp("#4fb870", "#a6f0b4", "#fbfff0"))
    # Boots peek out below the robe.
    for dx, lift, x in ((pose.back_dx, pose.back_lift, 8),
                        (pose.front_dx, pose.front_lift, 12)):
        c.rect((ox + x + dx, oy + 20 - lift, ox + x + dx + 3,
                oy + 21 - lift), BOOT)
    # Robe with cream trim.
    c.poly([(ox + 7, by + 12), (ox + 15, by + 12), (ox + 17, oy + 20),
            (ox + 5, oy + 20)], HEALER_CLOTH)
    c.rect((ox + 5, oy + 19, ox + 17, oy + 20), HEALER_TRIM)
    c.rect((ox + 11, by + 13, ox + 11, oy + 19), HEALER_TRIM,
           bevel=False)
    # Hood with the face opening and a little golden hair.
    c.ellipse((ox + 4, by + 1, ox + 18, by + 15), HEALER_CLOTH)
    c.poly([(ox + 5, by + 5), (ox + 1, by + 10), (ox + 6, by + 11)],
           HEALER_CLOTH)
    c.ellipse((ox + 9, by + 5, ox + 17, by + 14), SKIN)
    c.rect((ox + 10, by + 5, ox + 16, by + 6), GOLD)
    c.shape(lambda d: d.arc((ox + 8, by + 4, ox + 18, by + 15), 200,
                            340, fill=255), HEALER_TRIM, bevel=False)
    draw_face(c, ox + 12, by + 9)
    # Front hand on the staff.
    hand_y = by + 13 + raise_y
    c.rect((ox + 15, by + 13, ox + 18, by + 15), HEALER_CLOTH)
    c.rect((sx - 1, hand_y, sx + 1, hand_y + 1), SKIN, bevel=False)
    if pose.glow >= 1:
        sparks = [(-4, -3), (5, -2), (0, -6), (-3, 4), (4, 5)]
        for dx, dy in sparks[:2 + pose.glow]:
            c.dot(sx + dx, orb_y + dy, "#f4fff4")
    c.outline()
    return c


# --- rogue ----------------------------------------------------------

def draw_rogue(pose: Pose) -> Canvas:
    c = Canvas(FRAME, FRAME)
    ox, oy = body_origin(pose)
    lx = ox + pose.lean
    by = oy + pose.breathe
    # Scarf tail streams behind.
    f = pose.flutter
    c.poly([(ox + 8, by + 13), (ox + 1, by + 13 + f), (ox - 1, by + 16 + f),
            (ox + 3, by + 16 + f // 2), (ox + 8, by + 15)], GOLD)
    draw_legs(c, pose, ROGUE_LEATHER)
    c.rect((ox + 7, by + 13, ox + 15, by + 18), ROGUE_CLOTH)
    c.rect((ox + 7, by + 17, ox + 15, by + 17), ROGUE_LEATHER,
           bevel=False)
    c.dot(ox + 12, by + 17, "#ffe07a")
    # Hood with a masked face.
    c.ellipse((lx + 5, by + 2, lx + 17, by + 14), ROGUE_CLOTH)
    c.poly([(lx + 6, by + 3), (lx + 2, by + 0), (lx + 4, by + 7)],
           ROGUE_CLOTH)
    c.ellipse((lx + 10, by + 6, lx + 17, by + 13), SKIN)
    c.rect((lx + 10, by + 11, lx + 17, by + 13),
           Ramp("#15101f", "#2a2238", "#3d3450"))
    c.rect((ox + 7, by + 12, ox + 15, by + 13), GOLD)
    draw_face(c, lx + 12, by + 8, masked=True)
    # Front arm with a dagger or a stolen coin.
    if pose.arm == "grab":
        c.rect((ox + 14, by + 13, ox + 20, by + 14), ROGUE_CLOTH)
        c.ellipse((ox + 20, by + 10, ox + 24, by + 14), GOLD)
    else:
        c.rect((ox + 14, by + 13, ox + 16, by + 16), ROGUE_CLOTH)
        c.line([(ox + 17, by + 16), (ox + 20, by + 13)], "#dfe8f0")
        c.dot(ox + 16, by + 16, "#e0a526")
    c.outline()
    return c


# --- sheets ---------------------------------------------------------

def poses_for(kind: str) -> dict:
    poses = {
        "idle_0": Pose(IDLE_LEGS[0], breathe=0),
        "idle_1": Pose(IDLE_LEGS[1], breathe=1),
    }
    for index, legs in enumerate(WALK_LEGS):
        poses["walk_%d" % index] = Pose(legs, flutter=index % 2)
    if kind == "warrior":
        poses["crouch"] = Pose(crouch=2, arm="down")
        poses["leap"] = Pose(tuck=True, arm="raise")
        poses["slash"] = Pose(tuck=True, arm="slash")
    elif kind == "healer":
        for index in range(3):
            poses["cast_%d" % index] = Pose(glow=index)
    else:
        for index, legs in enumerate(RUN_LEGS):
            poses["run_%d" % index] = Pose(legs, lean=1,
                                           flutter=1 + index % 2)
        poses["grab"] = Pose(lean=1, arm="grab", flutter=2)
    return poses


DRAWERS = {
    "warrior": draw_warrior,
    "healer": draw_healer,
    "rogue": draw_rogue,
}


def build_sheet(kind: str) -> Image.Image:
    order = FRAME_ORDER[kind]
    poses = poses_for(kind)
    sheet = Image.new("RGBA", (FRAME * len(order), FRAME), (0, 0, 0, 0))
    for index, name in enumerate(order):
        frame = DRAWERS[kind](poses[name]).image
        sheet.paste(frame, (index * FRAME, 0))
    return sheet


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for kind in FRAME_ORDER:
        path = os.path.join(OUT_DIR, kind + ".png")
        build_sheet(kind).save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
