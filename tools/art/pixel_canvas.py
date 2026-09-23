"""Tiny pixel-art canvas used by the party art generators.

Shapes are rasterised into a mask and filled with a three-tone ramp
(highlight on the top-left edge, shadow on the bottom-right edge),
which gives every part a bevelled, hand-shaded look. A final pass adds
a dark outline around the whole silhouette.
"""

from PIL import Image, ImageDraw


def rgb(hex_code: str) -> tuple:
    hex_code = hex_code.lstrip("#")
    return tuple(int(hex_code[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Ramp:
    """Shadow / base / highlight colours for one material."""

    def __init__(self, dark: str, base: str, light: str) -> None:
        self.dark = rgb(dark)
        self.base = rgb(base)
        self.light = rgb(light)


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.image = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    # -- primitives -------------------------------------------------

    def shape(self, draw_fn, ramp: Ramp, bevel: bool = True) -> None:
        """Rasterise draw_fn(ImageDraw) into a mask and fill it."""
        mask = Image.new("L", (self.width, self.height), 0)
        draw_fn(ImageDraw.Draw(mask))
        px = mask.load()
        out = self.image.load()
        for y in range(self.height):
            for x in range(self.width):
                if not px[x, y]:
                    continue
                color = ramp.base
                if bevel:
                    lit = not self._in(px, x, y - 1) or \
                        not self._in(px, x - 1, y)
                    shaded = not self._in(px, x, y + 1) or \
                        not self._in(px, x + 1, y)
                    if lit and not shaded:
                        color = ramp.light
                    elif shaded and not lit:
                        color = ramp.dark
                out[x, y] = color

    def ellipse(self, box, ramp: Ramp, bevel: bool = True) -> None:
        self.shape(lambda d: d.ellipse(box, fill=255), ramp, bevel)

    def rect(self, box, ramp: Ramp, bevel: bool = True) -> None:
        self.shape(lambda d: d.rectangle(box, fill=255), ramp, bevel)

    def poly(self, points, ramp: Ramp, bevel: bool = True) -> None:
        self.shape(lambda d: d.polygon(points, fill=255), ramp, bevel)

    def line(self, points, color: str, width: int = 1) -> None:
        ImageDraw.Draw(self.image).line(points, fill=rgb(color), width=width)

    def dot(self, x: int, y: int, color: str) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self.image.putpixel((x, y), rgb(color))

    def dots(self, points, color: str) -> None:
        for x, y in points:
            self.dot(x, y, color)

    def clear(self, x: int, y: int) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self.image.putpixel((x, y), (0, 0, 0, 0))

    # -- finishing --------------------------------------------------

    def outline(self, color: str = "#1b1119") -> None:
        """Adds a 1px outline around every opaque pixel."""
        src = self.image.copy().load()
        out = self.image.load()
        edge = rgb(color)
        for y in range(self.height):
            for x in range(self.width):
                if src[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.width and 0 <= ny < self.height \
                            and src[nx, ny][3] and src[nx, ny][:3] != \
                            edge[:3]:
                        out[x, y] = edge
                        break

    def flipped(self) -> Image.Image:
        return self.image.transpose(Image.FLIP_LEFT_RIGHT)

    def _in(self, px, x: int, y: int) -> bool:
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return False
        return bool(px[x, y])
