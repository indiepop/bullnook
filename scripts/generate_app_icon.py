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
    """Draw a front-facing geometric bull head emphasizing ox horns."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    scale = size / SIZE

    def s(p: tuple[float, float]) -> tuple[float, float]:
        return (p[0] * scale, p[1] * scale)

    # Front-facing bull head shield (geometric silhouette)
    head_points = [
        s((512, 395)),  # top center between horns
        s((455, 415)),  # left forehead
        s((415, 470)),  # left temple
        s((385, 540)),  # left cheek
        s((400, 610)),  # left jaw
        s((512, 655)),  # chin
        s((624, 610)),  # right jaw
        s((639, 540)),  # right cheek
        s((609, 470)),  # right temple
        s((569, 415)),  # right forehead
    ]

    draw_polygon_radial_gradient(
        img,
        head_points,
        center_color=BRONZE_LIGHT,
        edge_color=BRONZE,
    )

    # Left horn: thick curve sweeping up and out
    draw_thick_curve(
        img,
        s((450, 420)),   # base
        s((330, 360)),   # control outward
        s((235, 285)),   # tip (up and out)
        width_start=34,
        width_end=10,
        color=(160, 100, 35, 255),
        steps=90,
    )
    # Horn highlight ridge
    draw_thick_curve(
        img,
        s((445, 405)),
        s((340, 350)),
        s((260, 290)),
        width_start=12,
        width_end=4,
        color=HIGHLIGHT + (255,),
        steps=90,
    )

    # Right horn: mirror
    draw_thick_curve(
        img,
        s((574, 420)),
        s((694, 360)),
        s((789, 285)),
        width_start=34,
        width_end=10,
        color=(160, 100, 35, 255),
        steps=90,
    )
    draw_thick_curve(
        img,
        s((579, 405)),
        s((684, 350)),
        s((764, 290)),
        width_start=12,
        width_end=4,
        color=HIGHLIGHT + (255,),
        steps=90,
    )

    # Eyes - smaller, darker, more bull-like
    eye_y = 510
    for ex in (450, 574):
        eye_x = s((ex, eye_y))[0]
        eye_y_scaled = s((ex, eye_y))[1]
        # Dark eye slit
        draw.ellipse(
            [eye_x - 9, eye_y_scaled - 6, eye_x + 9, eye_y_scaled + 6],
            fill=(40, 25, 10, 230),
        )
        # Small highlight
        draw.ellipse(
            [eye_x - 2, eye_y_scaled - 2, eye_x + 3, eye_y_scaled + 2],
            fill=HIGHLIGHT + (200,),
        )

    # Nostrils
    for nx in (485, 539):
        nostril_x = s((nx, 605))[0]
        nostril_y = s((nx, 605))[1]
        draw.ellipse(
            [nostril_x - 9, nostril_y - 6, nostril_x + 9, nostril_y + 6],
            fill=(50, 30, 10, 200),
        )

    # Soft shadow under head
    shadow_y = s((0, 685))[1]
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
