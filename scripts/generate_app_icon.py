"""Generate the BullNook golden bull app icon."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
CENTER = SIZE // 2

# Palette
LIGHT_GOLD = (255, 215, 0)      # #FFD700
MID_GOLD = (184, 134, 11)       # #B8860B
DARK_BRONZE = (139, 105, 20)    # #8B6914
BRONZE = (139, 69, 19)          # #8B4513
BRONZE_LIGHT = (160, 82, 45)    # #A0522D
HIGHLIGHT = (255, 223, 100)     # bright gold highlight
TEXT_COLOR = (255, 248, 220)    # #FFF8DC
SHADOW = (60, 40, 10, 120)


def lerp_color(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    """Linearly interpolate between two RGB colors."""
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_background(size: int = SIZE) -> Image.Image:
    """Draw a radial golden gradient background."""
    img = Image.new("RGBA", (size, size), DARK_BRONZE + (255,))
    draw = ImageDraw.Draw(img)
    center = size // 2
    max_radius = int((size * 0.85))

    for r in range(max_radius, 0, -2):
        t = r / max_radius
        if t < 0.5:
            color = lerp_color(LIGHT_GOLD, MID_GOLD, t * 2)
        else:
            color = lerp_color(MID_GOLD, DARK_BRONZE, (t - 0.5) * 2)
        draw.ellipse(
            [center - r, center - r, center + r, center + r],
            fill=color + (255,),
        )

    return img


if __name__ == "__main__":
    icon = draw_background()
    icon.save(ROOT / "app_icon_1024.png")
