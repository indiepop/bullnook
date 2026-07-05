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
HIGHLIGHT = (255, 235, 140)     # bright gold highlight
SPECULAR = (255, 250, 220)      # near-white specular
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
                color = lerp_color(base_color, highlight_color, t * 0.7)
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


def draw_metal_horn(
    img: Image.Image,
    base: tuple[float, float],
    control: tuple[float, float],
    tip: tuple[float, float],
    width_base: float,
    width_tip: float,
) -> None:
    """Draw a metallic gold horn with base shadow, body gradient, highlight ridge and specular spot."""
    # Dark underside shadow
    draw_thick_curve(
        img,
        (base[0] + 8, base[1] + 8),
        (control[0] + 6, control[1] + 6),
        (tip[0] + 4, tip[1] + 4),
        width_base * 0.9,
        width_tip * 0.9,
        (60, 35, 10, 140),
        steps=100,
    )

    # Main horn body: gradient from bronze base to gold tip
    for i in range(100):
        t = i / 99
        x = (1 - t) ** 2 * base[0] + 2 * (1 - t) * t * control[0] + t ** 2 * tip[0]
        y = (1 - t) ** 2 * base[1] + 2 * (1 - t) * t * control[1] + t ** 2 * tip[1]
        w = width_base * (1 - t) + width_tip * t
        # Color transitions from dark bronze to bright gold
        body_color = lerp_color((120, 70, 25), (255, 215, 90), t)
        draw = ImageDraw.Draw(img)
        draw.ellipse([x - w, y - w, x + w, y + w], fill=body_color + (255,))

    # Bright highlight ridge along top/outside
    draw_thick_curve(
        img,
        (base[0] - 8, base[1] - 8),
        (control[0] - 6, control[1] - 6),
        (tip[0] - 3, tip[1] - 3),
        width_base * 0.35,
        width_tip * 0.35,
        HIGHLIGHT + (255,),
        steps=100,
    )

    # Sharp specular spot near the upper curve
    spec_t = 0.55
    spec_x = (1 - spec_t) ** 2 * base[0] + 2 * (1 - spec_t) * spec_t * control[0] + spec_t ** 2 * tip[0]
    spec_y = (1 - spec_t) ** 2 * base[1] + 2 * (1 - spec_t) * spec_t * control[1] + spec_t ** 2 * tip[1]
    spec_w = width_base * (1 - spec_t) + width_tip * spec_t
    draw = ImageDraw.Draw(img)
    draw.ellipse(
        [spec_x - spec_w * 0.25, spec_y - spec_w * 0.35, spec_x + spec_w * 0.15, spec_y + spec_w * 0.15],
        fill=SPECULAR + (200,),
    )


def draw_bull(size: int = SIZE) -> Image.Image:
    """Draw a front-facing metallic bull head with upward-pointing horns."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    scale = size / SIZE

    def s(p: tuple[float, float]) -> tuple[float, float]:
        return (p[0] * scale, p[1] * scale)

    # Main bull head: rounded shield shape
    head_points = [
        s((512, 405)),  # top center between horns
        s((470, 410)),  # left forehead upper
        s((430, 430)),  # left forehead
        s((395, 465)),  # left temple
        s((372, 515)),  # left cheek upper
        s((365, 570)),  # left cheek lower
        s((385, 625)),  # left jaw
        s((440, 660)),  # left chin corner
        s((512, 675)),  # chin center
        s((584, 660)),  # right chin corner
        s((639, 625)),  # right jaw
        s((659, 570)),  # right cheek lower
        s((652, 515)),  # right cheek upper
        s((629, 465)),  # right temple
        s((594, 430)),  # right forehead
        s((554, 410)),  # right forehead upper
    ]

    draw_polygon_radial_gradient(
        img,
        head_points,
        center_color=(180, 110, 55),
        edge_color=(110, 60, 25),
    )

    # Metallic rim light on left and right edges of face
    rim_left = [
        s((365, 560)),
        s((375, 470)),
        s((395, 445)),
        s((385, 465)),
        s((370, 555)),
    ]
    draw_polygon_gradient(img, rim_left, (80, 45, 20), HIGHLIGHT, highlight_direction=(-1, 0))
    rim_right = [
        s((659, 560)),
        s((649, 470)),
        s((629, 445)),
        s((639, 465)),
        s((654, 555)),
    ]
    draw_polygon_gradient(img, rim_right, (80, 45, 20), HIGHLIGHT, highlight_direction=(1, 0))

    # Upward-pointing metallic horns - thick, curved up and slightly outward
    draw_metal_horn(
        img,
        s((445, 430)),   # base
        s((350, 340)),   # control up and out
        s((390, 255)),   # tip up and slightly out
        width_base=52,
        width_tip=16,
    )
    draw_metal_horn(
        img,
        s((579, 430)),
        s((674, 340)),
        s((634, 255)),
        width_base=52,
        width_tip=16,
    )

    # Forehead center shine
    draw.ellipse([s((492, 420))[0], s((492, 420))[1], s((532, 450))[0], s((532, 450))[1]],
                 fill=HIGHLIGHT + (60,))

    # Angry brow ridges - dark brown, solid
    brow_color = (85, 48, 26, 230)
    # Left brow
    draw.polygon(
        [s((445, 485)), s((495, 495)), s((505, 520)), s((455, 515))],
        fill=brow_color,
    )
    # Right brow
    draw.polygon(
        [s((579, 485)), s((529, 495)), s((519, 520)), s((569, 515))],
        fill=brow_color,
    )

    # Eyes - fierce white with black pupils
    for ex, ey in ((465, 535), (559, 535)):
        eye_x = s((ex, ey))[0]
        eye_y = s((ex, ey))[1]
        draw.ellipse(
            [eye_x - 14, eye_y - 8, eye_x + 14, eye_y + 8],
            fill=TEXT_COLOR,
        )
        draw.ellipse(
            [eye_x - 8, eye_y - 4, eye_x + 8, eye_y + 4],
            fill=(25, 15, 5, 250),
        )
        draw.ellipse(
            [eye_x - 3, eye_y - 2, eye_x + 3, eye_y + 2],
            fill=SPECULAR + (180,),
        )

    # Forehead furrow lines
    draw.line([s((495, 440)), s((512, 450)), s((529, 440))], fill=(70, 40, 22, 150), width=3)

    # Nose ring (bright gold)
    ring_x, ring_y = s((512, 615))
    draw.ellipse([ring_x - 11, ring_y - 11, ring_x + 11, ring_y + 11], outline=HIGHLIGHT + (255,), width=4)
    draw.ellipse([ring_x - 3, ring_y - 3, ring_x + 3, ring_y + 3], fill=HIGHLIGHT + (255,))

    # Flaring nostrils
    for nx in (492, 532):
        nostril_x = s((nx, 595))[0]
        nostril_y = s((nx, 595))[1]
        draw.ellipse(
            [nostril_x - 11, nostril_y - 7, nostril_x + 11, nostril_y + 7],
            fill=(35, 22, 10, 240),
        )

    # Mouth line
    draw.arc(
        [s((475, 635))[0], s((475, 635))[1], s((549, 665))[0], s((549, 665))[1]],
        start=200,
        end=340,
        fill=(55, 32, 18, 190),
        width=3,
    )

    # Soft shadow under head
    shadow_y = s((0, 700))[1]
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
