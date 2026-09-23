"""Writes a SpriteFrames resource for every chibi sheet.

Run from the project root after the sheets are imported by Godot:
    python tools/art/write_sprite_frames.py

Outputs art/party/chibi/<class>_frames.tres. Frame order comes from
generate_chibi_art.FRAME_ORDER.
"""

import os
import random
import re

from generate_chibi_art import FRAME, FRAME_ORDER, OUT_DIR

# name: (frames, speed, loop)
ANIMATIONS = {
    "warrior": {
        "idle": (["idle_0", "idle_1"], 3.0, True),
        "walk": (["walk_0", "walk_1", "walk_2", "walk_3"], 12.0, True),
        "crouch": (["crouch"], 1.0, False),
        "leap": (["leap"], 1.0, False),
        "slash": (["slash"], 1.0, False),
    },
    "healer": {
        "idle": (["idle_0", "idle_1"], 3.0, True),
        "walk": (["walk_0", "walk_1", "walk_2", "walk_3"], 12.0, True),
        "cast": (["cast_0", "cast_1", "cast_2"], 14.0, False),
    },
    "rogue": {
        "idle": (["idle_0", "idle_1"], 3.0, True),
        "walk": (["walk_0", "walk_1", "walk_2", "walk_3"], 12.0, True),
        "run": (["run_0", "run_1", "run_2", "run_3"], 20.0, True),
        "grab": (["grab"], 1.0, False),
    },
}


def texture_uid(png_path: str) -> str:
    with open(png_path + ".import", encoding="utf-8") as handle:
        match = re.search(r'uid="(uid://[a-z0-9]+)"', handle.read())
    return match.group(1)


def existing_uid(tres_path: str) -> str:
    if not os.path.exists(tres_path):
        return ""
    with open(tres_path, encoding="utf-8") as handle:
        match = re.search(r'uid="(uid://[a-z0-9]+)"', handle.readline())
    return match.group(1) if match else ""


def new_uid() -> str:
    # Godot encodes a random 63-bit id in base 34 using a-y and 0-8.
    value = random.getrandbits(63)
    text = ""
    while True:
        digit = value % 34
        text = (chr(ord("a") + digit) if digit < 25
                else chr(ord("0") + digit - 25)) + text
        value //= 34
        if value == 0:
            return "uid://" + text


def write(kind: str) -> None:
    png = os.path.join(OUT_DIR, kind + ".png")
    tres = os.path.join(OUT_DIR, kind + "_frames.tres")
    order = FRAME_ORDER[kind]
    uid = existing_uid(tres) or new_uid()
    lines = [
        '[gd_resource type="SpriteFrames" format=3 uid="%s"]' % uid,
        "",
        '[ext_resource type="Texture2D" uid="%s" '
        'path="res://art/party/chibi/%s.png" id="1_sheet"]'
        % (texture_uid(png), kind),
        "",
    ]
    for index, name in enumerate(order):
        lines += [
            '[sub_resource type="AtlasTexture" id="Atlas_%s"]' % name,
            'atlas = ExtResource("1_sheet")',
            "region = Rect2(%d, 0, %d, %d)" % (index * FRAME, FRAME, FRAME),
            "",
        ]
    blocks = []
    for anim, (frames, speed, loop) in ANIMATIONS[kind].items():
        frame_text = ", ".join(
            '{\n"duration": 1.0,\n"texture": SubResource("Atlas_%s")\n}'
            % name for name in frames
        )
        blocks.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n'
            '"speed": %.1f\n}'
            % (frame_text, "true" if loop else "false", anim, speed)
        )
    lines += ["[resource]", "animations = [%s]" % ", ".join(blocks), ""]
    with open(tres, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))
    print("wrote", tres)


def main() -> None:
    for kind in ANIMATIONS:
        write(kind)


if __name__ == "__main__":
    main()
