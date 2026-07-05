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


def draw_thick_curve(
    img: Image.Image,
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    width_start: float,
    width_end: float,
    color: tuple[int, int, int, int],
    steps: int = 80,
) -> None:
    """Draw a thick quadratic Bezier curve as a series of overlapping circles."""
    draw = ImageDraw.Draw(img)
    for i in range(steps + 1):
        t = i / steps
        # Quadratic Bezier
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        w = width_start * (1 - t) + width_end * t
        draw.ellipse([x - w, y - w, x + w, y + w], fill=color)


# Metallic gold/bronze colors for horns
HORN_BASE = (180, 120, 50, 255)
HORN_TIP = (120, 80, 30, 255)
HORN_HIGHLIGHT = (255, 230, 140, 255)


def draw_bull(size: int = SIZE) -> Image.Image:
    """Draw a realistic side-profile bull looking back, centered on a transparent canvas."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Coordinates are for a 1024 canvas; scale if needed
    scale = size / SIZE

    def s(p: tuple[float, float]) -> tuple[float, float]:
        return (p[0] * scale, p[1] * scale)

    # Main body + head silhouette (no horns, they are drawn separately)
    body_points = [
        s((515, 770)),  # belly rear
        s((445, 755)),  # belly mid
        s((395, 720)),  # chest bottom
        s((355, 670)),  # front leg / chest
        s((335, 610)),  # thick neck base front
        s((315, 565)),  # jaw bottom
        s((275, 540)),  # chin
        s((230, 520)),  # nose tip
        s((245, 490)),  # upper lip
        s((265, 470)),  # nose bridge
        s((300, 460)),  # forehead lower
        s((340, 460)),  # forehead top
        s((375, 470)),  # front horn base
        s((410, 470)),  # between horns
        s((445, 470)),  # back horn base
        s((475, 490)),  # poll / top of head
        s((500, 480)),  # small ear base
        s((520, 505)),  # ear tip
        s((540, 525)),  # back of head
        s((580, 550)),  # neck back upper
        s((640, 575)),  # shoulder hump
        s((705, 615)),  # back
        s((720, 670)),  # rear upper
        s((690, 730)),  # rear bottom
        s((610, 765)),  # rump
    ]

    draw_polygon_gradient(
        img,
        body_points,
        base_color=BRONZE,
        highlight_color=HIGHLIGHT,
        highlight_direction=(0.25, -1),
    )

    # Front horn: thick crescent using quadratic bezier, extends outward and curls up
    draw_thick_curve(
        img,
        s((385, 468)),   # base
        s((260, 440)),   # control point (outward)
        s((225, 360)),   # tip (out and slightly up)
        width_start=28,
        width_end=12,
        color=HORN_BASE,
        steps=80,
    )
    # Highlight ridge on front horn
    draw_thick_curve(
        img,
        s((385, 455)),
        s((275, 430)),
        s((245, 360)),
        width_start=10,
        width_end=4,
        color=HORN_HIGHLIGHT,
        steps=80,
    )

    # Back horn: mirror of front horn, extends outward and curls up
    draw_thick_curve(
        img,
        s((435, 468)),   # base
        s((560, 440)),   # control point (outward)
        s((600, 360)),   # tip (out and slightly up)
        width_start=28,
        width_end=12,
        color=HORN_BASE,
        steps=80,
    )
    # Highlight ridge on back horn
    draw_thick_curve(
        img,
        s((435, 455)),
        s((545, 430)),
        s((580, 360)),
        width_start=10,
        width_end=4,
        color=HORN_HIGHLIGHT,
        steps=80,
    )

    # Eye (white with dark pupil)
    eye_x, eye_y = s((305, 490))
    draw.ellipse([eye_x - 10, eye_y - 10, eye_x + 10, eye_y + 10], fill=TEXT_COLOR)
    draw.ellipse([eye_x - 5, eye_y - 5, eye_x + 5, eye_y + 5], fill=(30, 20, 5, 230))
    draw.ellipse([eye_x - 2, eye_y - 2, eye_x + 2, eye_y + 2], fill=TEXT_COLOR)

    # Nostril
    nostril_x, nostril_y = s((238, 510))
    draw.ellipse([nostril_x - 8, nostril_y - 5, nostril_x + 8, nostril_y + 5], fill=(50, 30, 10, 200))

    # Nose ring (small golden ring) - classic bull marker
    ring_x, ring_y = s((235, 535))
    draw.ellipse([ring_x - 10, ring_y - 10, ring_x + 10, ring_y + 10], outline=HIGHLIGHT + (255,), width=3)
    draw.ellipse([ring_x - 3, ring_y - 3, ring_x + 3, ring_y + 3], fill=HIGHLIGHT + (255,))

    # Mouth line
    draw.line([s((255, 545)), s((290, 535))], fill=(80, 50, 20, 180), width=3)

    # Small ear inner shadow
    ear_x, ear_y = s((510, 490))
    draw.ellipse([ear_x - 10, ear_y - 14, ear_x + 7, ear_y + 7], fill=(100, 60, 30, 160))

    # Soft shadow under bull
    shadow_y = s((0, 790))[1]
    draw.ellipse(
        [s((380, 0))[0], shadow_y, s((680, 0))[0], shadow_y + 45],
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
    old_icon = ROOT / "app_icon_1024.png"
    backup = ROOT / "app_icon_1024_horn.png"
    if old_icon.exists() and not backup.exists():
        old_icon.rename(backup)

    icon = compose_icon()
    icon.save(ROOT / "app_icon_1024.png")
