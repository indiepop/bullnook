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


def draw_polygon_gradient(
    img: Image.Image,
    points: list[tuple[float, float]],
    base_color: tuple[int, int, int],
    highlight_color: tuple[int, int, int],
    highlight_direction: tuple[float, float] = (0, -1),
) -> None:
    """Fill a polygon with a subtle directional gradient."""
    mask = Image.new("L", img.size, 0)
    draw_mask = ImageDraw.Draw(mask)
    draw_mask.polygon(points, fill=255)

    # Create gradient layer, transparent outside the polygon
    grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pixels = grad.load()
    min_x = min(p[0] for p in points)
    max_x = max(p[0] for p in points)
    min_y = min(p[1] for p in points)
    max_y = max(p[1] for p in points)

    dx, dy = highlight_direction
    for y in range(int(min_y), int(max_y) + 1):
        for x in range(int(min_x), int(max_x) + 1):
            if mask.getpixel((x, y)):
                # normalized position within bounding box
                nx = (x - min_x) / (max_x - min_x) if max_x != min_x else 0
                ny = (y - min_y) / (max_y - min_y) if max_y != min_y else 0
                t = nx * dx + ny * dy
                t = max(0.0, min(1.0, (t + 1) / 2))
                color = lerp_color(base_color, highlight_color, t * 0.6)
                pixels[x, y] = color + (255,)

    img.alpha_composite(grad)


def draw_bull(size: int = SIZE) -> Image.Image:
    """Draw a side-profile bull looking back, centered on a transparent canvas."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Coordinates are for a 1024 canvas; scale if needed
    scale = size / SIZE

    def s(p: tuple[float, float]) -> tuple[float, float]:
        return (p[0] * scale, p[1] * scale)

    # Bull silhouette: head facing left, looking back toward upper right
    bull_points = [
        s((420, 680)),  # chest bottom
        s((360, 620)),  # neck base
        s((330, 520)),  # neck top
        s((280, 480)),  # jaw
        s((260, 420)),  # nose
        s((280, 380)),  # forehead start
        s((340, 360)),  # forehead top
        s((380, 300)),  # horn base front
        s((360, 220)),  # horn tip front
        s((400, 280)),  # horn base back
        s((430, 360)),  # between horns
        s((460, 260)),  # back horn tip
        s((480, 360)),  # back horn base
        s((500, 420)),  # poll/top of head
        s((520, 480)),  # ear/back of head
        s((560, 520)),  # back of neck
        s((620, 580)),  # shoulder hump
        s((640, 660)),  # back line
        s((600, 720)),  # rear
        s((500, 740)),  # belly
    ]

    draw_polygon_gradient(
        img,
        bull_points,
        base_color=BRONZE,
        highlight_color=HIGHLIGHT,
        highlight_direction=(0.3, -1),
    )

    # Eye highlight
    eye_x, eye_y = s((310, 430))
    draw.ellipse([eye_x - 8, eye_y - 8, eye_x + 8, eye_y + 8], fill=TEXT_COLOR)

    # Nostril shadow
    nostril_x, nostril_y = s((270, 420))
    draw.ellipse([nostril_x - 6, nostril_y - 4, nostril_x + 6, nostril_y + 4], fill=(50, 30, 10, 180))

    # Soft shadow under bull
    shadow_y = s((0, 760))[1]
    draw.ellipse(
        [s((320, 0))[0], shadow_y, s((680, 0))[0], shadow_y + 40],
        fill=SHADOW,
    )

    return img


def compose_icon(size: int = SIZE) -> Image.Image:
    """Compose background + bull + text into the final icon."""
    icon = draw_background(size)
    bull = draw_bull(size)
    icon.alpha_composite(bull)
    icon = draw_text(icon)
    return icon


def draw_text(img: Image.Image, text: str = "BullNook") -> Image.Image:
    """Draw the brand name centered near the bottom."""
    from PIL import ImageFont

    draw = ImageDraw.Draw(img)
    size = img.size[0]

    # Try to load a system sans-serif font; fall back to default
    font_size = int(size * 0.09)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except OSError:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", font_size)
        except OSError:
            font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (size - text_width) // 2
    y = int(size * 0.82) - text_height // 2

    # Subtle shadow for readability on gold
    draw.text((x + 3, y + 3), text, font=font, fill=(60, 40, 10, 160))
    draw.text((x, y), text, font=font, fill=TEXT_COLOR + (255,))
    return img


if __name__ == "__main__":
    icon = compose_icon()
    icon.save(ROOT / "app_icon_1024.png")
