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
HIGHLIGHT = (255, 230, 120)     # bright gold highlight
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


def draw_polygon_radial_gradient(
    img: Image.Image,
    points: list[tuple[float, float]],
    center_color: tuple[int, int, int],
    edge_color: tuple[int, int, int],
) -> None:
    """Fill a polygon with a radial gradient from its centroid."""
    mask = Image.new("L", img.size, 0)
    draw_mask = ImageDraw.Draw(mask)
    draw_mask.polygon(points, fill=255)

    # Centroid
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    max_dist = max(((p[0] - cx) ** 2 + (p[1] - cy) ** 2) ** 0.5 for p in points)

    grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pixels = grad.load()
    min_x = max(0, int(min(p[0] for p in points)))
    max_x = min(img.size[0] - 1, int(max(p[0] for p in points)))
    min_y = max(0, int(min(p[1] for p in points)))
    max_y = min(img.size[1] - 1, int(max(p[1] for p in points)))

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            if mask.getpixel((x, y)):
                dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                t = min(1.0, dist / max_dist) if max_dist > 0 else 0
                color = lerp_color(center_color, edge_color, t)
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
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        w = width_start * (1 - t) + width_end * t
        draw.ellipse([x - w, y - w, x + w, y + w], fill=color)


def draw_bull(size: int = SIZE) -> Image.Image:
    """Draw a front-facing bull head inspired by the Chicago Bulls logo."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    scale = size / SIZE

    def s(p: tuple[float, float]) -> tuple[float, float]:
        return (p[0] * scale, p[1] * scale)

    # Main bull head: rounded shield shape
    head_points = [
        s((512, 395)),  # top center between horns
        s((470, 400)),  # left forehead upper
        s((430, 420)),  # left forehead
        s((395, 455)),  # left temple
        s((372, 505)),  # left cheek upper
        s((365, 560)),  # left cheek lower
        s((385, 615)),  # left jaw
        s((440, 650)),  # left chin corner
        s((512, 665)),  # chin center
        s((584, 650)),  # right chin corner
        s((639, 615)),  # right jaw
        s((659, 560)),  # right cheek lower
        s((652, 505)),  # right cheek upper
        s((629, 455)),  # right temple
        s((594, 420)),  # right forehead
        s((554, 400)),  # right forehead upper
    ]

    draw_polygon_radial_gradient(
        img,
        head_points,
        center_color=BRONZE_LIGHT,
        edge_color=BRONZE,
    )

    # Left horn: two-segment thick curve for angular Chicago Bulls shape
    # Segment 1: base up and out
    draw_thick_curve(
        img,
        s((445, 425)),
        s((405, 395)),
        s((360, 365)),
        width_start=44,
        width_end=32,
        color=(170, 110, 45, 255),
        steps=60,
    )
    # Segment 2: forward and down to tip
    draw_thick_curve(
        img,
        s((360, 365)),
        s((355, 450)),
        s((405, 540)),
        width_start=32,
        width_end=16,
        color=(170, 110, 45, 255),
        steps=80,
    )
    # Highlights
    draw_thick_curve(
        img,
        s((440, 410)),
        s((405, 385)),
        s((365, 360)),
        width_start=14,
        width_end=10,
        color=HIGHLIGHT + (255,),
        steps=60,
    )
    draw_thick_curve(
        img,
        s((365, 370)),
        s((362, 445)),
        s((408, 525)),
        width_start=10,
        width_end=5,
        color=HIGHLIGHT + (255,),
        steps=80,
    )

    # Right horn: mirror
    draw_thick_curve(
        img,
        s((579, 425)),
        s((619, 395)),
        s((664, 365)),
        width_start=44,
        width_end=32,
        color=(170, 110, 45, 255),
        steps=60,
    )
    draw_thick_curve(
        img,
        s((664, 365)),
        s((669, 450)),
        s((619, 540)),
        width_start=32,
        width_end=16,
        color=(170, 110, 45, 255),
        steps=80,
    )
    draw_thick_curve(
        img,
        s((584, 410)),
        s((619, 385)),
        s((659, 360)),
        width_start=14,
        width_end=10,
        color=HIGHLIGHT + (255,),
        steps=60,
    )
    draw_thick_curve(
        img,
        s((659, 370)),
        s((662, 445)),
        s((616, 525)),
        width_start=10,
        width_end=5,
        color=HIGHLIGHT + (255,),
        steps=80,
    )

    # Angry brow ridges - dark brown, solid
    brow_color = (95, 52, 30, 230)
    # Left brow
    draw.polygon(
        [s((445, 475)), s((495, 485)), s((505, 510)), s((455, 505))],
        fill=brow_color,
    )
    # Right brow
    draw.polygon(
        [s((579, 475)), s((529, 485)), s((519, 510)), s((569, 505))],
        fill=brow_color,
    )

    # Eyes - Chicago Bulls style: white with black pupils
    for ex, ey in ((465, 525), (559, 525)):
        eye_x = s((ex, ey))[0]
        eye_y = s((ex, ey))[1]
        # White of eye
        draw.ellipse(
            [eye_x - 14, eye_y - 8, eye_x + 14, eye_y + 8],
            fill=TEXT_COLOR,
        )
        # Black pupil
        draw.ellipse(
            [eye_x - 8, eye_y - 4, eye_x + 8, eye_y + 4],
            fill=(25, 15, 5, 250),
        )
        # Highlight
        draw.ellipse(
            [eye_x - 3, eye_y - 2, eye_x + 3, eye_y + 2],
            fill=HIGHLIGHT + (180,),
        )

    # Forehead furrow lines
    draw.line([s((495, 430)), s((512, 440)), s((529, 430))], fill=(80, 45, 25, 150), width=3)

    # Nose ring (golden)
    ring_x, ring_y = s((512, 605))
    draw.ellipse([ring_x - 10, ring_y - 10, ring_x + 10, ring_y + 10], outline=HIGHLIGHT + (255,), width=3)
    draw.ellipse([ring_x - 3, ring_y - 3, ring_x + 3, ring_y + 3], fill=HIGHLIGHT + (255,))

    # Flaring nostrils
    for nx in (492, 532):
        nostril_x = s((nx, 585))[0]
        nostril_y = s((nx, 585))[1]
        draw.ellipse(
            [nostril_x - 11, nostril_y - 7, nostril_x + 11, nostril_y + 7],
            fill=(35, 22, 10, 240),
        )

    # Mouth line - slight frown/aggression
    draw.arc(
        [s((475, 625))[0], s((475, 625))[1], s((549, 655))[0], s((549, 655))[1]],
        start=200,
        end=340,
        fill=(55, 32, 18, 190),
        width=3,
    )

    # Soft shadow under head
    shadow_y = s((0, 690))[1]
    draw.ellipse(
        [s((380, 0))[0], shadow_y, s((644, 0))[0], shadow_y + 40],
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
