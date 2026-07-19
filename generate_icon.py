"""Generate the BullNook tough red bull app icon."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SIZE = 1024
ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "app_icon_cartoon_bull.png"
ASSET = (
    ROOT
    / "BullNook"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "AppIcon.png"
)

# Palette
RED = (218, 28, 28)              # main red
RED_DARK = (150, 10, 10)         # shadow
RED_LIGHT = (255, 82, 82)        # highlight
GOLD = (255, 200, 45)            # horns / money
GOLD_DARK = (185, 135, 18)       # horn shadow / coin shadow
GOLD_LIGHT = (255, 240, 140)     # horn highlight
BG = (48, 6, 6)                  # deep red-brown background
BG_GLOW = (105, 12, 12)          # subtle center glow
OUTLINE = (26, 4, 4)             # near-black outline
WHITE = (255, 255, 255)
GREEN_BILL = (30, 130, 65)       # cartoon dollar green


def draw_background(draw: ImageDraw.ImageDraw) -> None:
    """Draw a flat dark-red background with a subtle radial glow."""
    draw.rectangle([0, 0, SIZE, SIZE], fill=BG)
    center = SIZE // 2
    for r in range(center, 0, -10):
        t = r / center
        color = (
            int(BG_GLOW[0] * (1 - t) + BG[0] * t),
            int(BG_GLOW[1] * (1 - t) + BG[1] * t),
            int(BG_GLOW[2] * (1 - t) + BG[2] * t),
        )
        draw.ellipse([center - r, center - r, center + r, center + r], fill=color)


def draw_polygon_with_outline(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int],
    outline: tuple[int, int, int] = OUTLINE,
    outline_width: int = 10,
) -> None:
    """Draw a polygon with a thick outline by expanding it."""
    for dx, dy in [
        (-outline_width, 0),
        (outline_width, 0),
        (0, -outline_width),
        (0, outline_width),
        (-outline_width // 2, -outline_width // 2),
        (outline_width // 2, -outline_width // 2),
        (-outline_width // 2, outline_width // 2),
        (outline_width // 2, outline_width // 2),
    ]:
        shifted = [(p[0] + dx, p[1] + dy) for p in points]
        draw.polygon(shifted, fill=outline)
    draw.polygon(points, fill=fill)


def draw_horn(
    draw: ImageDraw.ImageDraw,
    base: tuple[float, float],
    mid: tuple[float, float],
    tip: tuple[float, float],
    width_base: float = 50,
    width_tip: float = 12,
) -> None:
    """Draw a smooth strong golden horn as a filled polygon."""
    steps = 60
    top_edge = []
    bottom_edge = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * base[0] + 2 * (1 - t) * t * mid[0] + t ** 2 * tip[0]
        y = (1 - t) ** 2 * base[1] + 2 * (1 - t) * t * mid[1] + t ** 2 * tip[1]
        dx = 2 * (1 - t) * (mid[0] - base[0]) + 2 * t * (tip[0] - mid[0])
        dy = 2 * (1 - t) * (mid[1] - base[1]) + 2 * t * (tip[1] - mid[1])
        length = (dx ** 2 + dy ** 2) ** 0.5
        if length == 0:
            length = 1
        perp_x = -dy / length
        perp_y = dx / length
        w = width_base * (1 - t) + width_tip * t
        top_edge.append((x + perp_x * w, y + perp_y * w))
        bottom_edge.append((x - perp_x * w, y - perp_y * w))

    # Outline
    outline_points = top_edge + bottom_edge[::-1]
    for offset in range(8, 0, -2):
        expanded = []
        for x, y in outline_points:
            expanded.append((x + (x - base[0]) * offset * 0.01 + offset * 0.3,
                             y + (y - base[1]) * offset * 0.01 + offset * 0.3))
        draw.polygon(expanded, fill=OUTLINE)

    draw.polygon(outline_points, fill=GOLD)

    # Highlight ridge
    ridge_top = []
    ridge_bottom = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * (base[0] - 8) + 2 * (1 - t) * t * (mid[0] - 6) + t ** 2 * (tip[0] - 3)
        y = (1 - t) ** 2 * (base[1] - 8) + 2 * (1 - t) * t * (mid[1] - 6) + t ** 2 * (tip[1] - 3)
        dx = 2 * (1 - t) * ((mid[0] - 6) - (base[0] - 8)) + 2 * t * ((tip[0] - 3) - (mid[0] - 6))
        dy = 2 * (1 - t) * ((mid[1] - 6) - (base[1] - 8)) + 2 * t * ((tip[1] - 3) - (mid[1] - 6))
        length = (dx ** 2 + dy ** 2) ** 0.5
        if length == 0:
            length = 1
        perp_x = -dy / length
        perp_y = dx / length
        w = (width_base * (1 - t) + width_tip * t) * 0.25
        ridge_top.append((x + perp_x * w, y + perp_y * w))
        ridge_bottom.append((x - perp_x * w, y - perp_y * w))
    draw.polygon(ridge_top + ridge_bottom[::-1], fill=GOLD_LIGHT)


def draw_coin(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    radius: float,
) -> None:
    """Draw a gold coin with a $ symbol."""
    draw.ellipse(
        [cx - radius - 6, cy - radius - 6, cx + radius + 6, cy + radius + 6],
        fill=OUTLINE,
    )
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=GOLD)
    draw.ellipse(
        [cx - radius * 0.72, cy - radius * 0.72, cx + radius * 0.72, cy + radius * 0.72],
        outline=GOLD_DARK,
        width=4,
    )
    font_size = int(radius * 1.3)
    font = ImageFont.load_default()
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except OSError:
        pass
    bbox = draw.textbbox((0, 0), "$", font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw / 2, cy - th / 2 - 2), "$", font=font, fill=GOLD_DARK)
    draw.ellipse([cx - radius * 0.5, cy - radius * 0.5, cx - radius * 0.15, cy - radius * 0.15], fill=GOLD_LIGHT)


def draw_bill(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    angle: float = 15,
) -> None:
    """Draw a cartoon US dollar bill."""
    import math
    w, h = 120, 56
    rad = math.radians(angle)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)

    def rot(x: float, y: float) -> tuple[float, float]:
        return (cx + x * cos_a - y * sin_a, cy + x * sin_a + y * cos_a)

    corners = [rot(-w / 2, -h / 2), rot(w / 2, -h / 2), rot(w / 2, h / 2), rot(-w / 2, h / 2)]
    draw.polygon(corners, fill=OUTLINE)
    inner = [(x + (cx - x) * 0.06, y + (cy - y) * 0.06) for x, y in corners]
    draw.polygon(inner, fill=GREEN_BILL)

    # Decorative border
    bw, bh = w * 0.84, h * 0.74
    border = [rot(-bw / 2, -bh / 2), rot(bw / 2, -bh / 2), rot(bw / 2, bh / 2), rot(-bw / 2, bh / 2)]
    for i in range(4):
        draw.line([border[i], border[(i + 1) % 4]], fill=GOLD, width=3)

    # Center oval with $
    c = rot(0, 0)
    draw.ellipse([c[0] - 20, c[1] - 13, c[0] + 20, c[1] + 13], outline=GOLD, width=3)
    font_size = 28
    font = ImageFont.load_default()
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except OSError:
        pass
    bbox = draw.textbbox((0, 0), "$", font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((c[0] - tw / 2, c[1] - th / 2 - 2), "$", font=font, fill=GOLD)

    # Corner $
    for sx, sy in [(-w / 2 + 14, -h / 2 + 14), (w / 2 - 14, -h / 2 + 14),
                   (w / 2 - 14, h / 2 - 18), (-w / 2 + 14, h / 2 - 18)]:
        p = rot(sx, sy)
        draw.text((p[0] - 6, p[1] - 8), "$", font=font, fill=GOLD)


def draw_bull(draw: ImageDraw.ImageDraw) -> None:
    """Draw a tough charging bull with large bullish head and hard body."""
    # Ground shadow
    draw.ellipse([100, 910, 820, 970], fill=(0, 0, 0, 90))

    # Far legs (darker, behind)
    draw.polygon(
        [(250, 700), (300, 700), (290, 820), (240, 820), (235, 950), (290, 950), (300, 980), (225, 980)],
        fill=OUTLINE,
    )
    draw.polygon(
        [(258, 708), (292, 708), (284, 812), (246, 812), (242, 942), (284, 942), (292, 972), (234, 972)],
        fill=RED_DARK,
    )
    draw.polygon(
        [(590, 720), (650, 720), (640, 830), (580, 830), (570, 950), (635, 950), (645, 985), (560, 985)],
        fill=OUTLINE,
    )
    draw.polygon(
        [(598, 728), (642, 728), (634, 822), (588, 822), (580, 942), (630, 942), (638, 975), (570, 975)],
        fill=RED_DARK,
    )

    # Tail
    tail_points = [(155, 560), (95, 470), (40, 390), (80, 430), (170, 540)]
    draw_polygon_with_outline(draw, tail_points, fill=RED_DARK, outline_width=10)
    draw.polygon([(40, 390), (5, 335), (65, 355)], fill=OUTLINE)
    draw.polygon([(43, 388), (17, 345), (59, 360)], fill=RED)

    # Main body silhouette - muscular charging bull with big hump
    silhouette = [
        (940, 520),  # nose tip (narrower)
        (965, 475),  # nose top
        (955, 400),  # forehead
        (900, 350),  # top front head
        (820, 345),  # top back head
        (760, 380),  # neck top
        (700, 290),  # shoulder hump (much higher)
        (560, 325),  # withers
        (420, 360),  # back
        (260, 410),  # mid back
        (160, 480),  # rump top (smaller)
        (130, 580),  # rump back
        (140, 700),  # rump bottom
        (205, 700),  # back leg top front
        (200, 790),  # back leg knee
        (190, 960),  # back hoof front
        (270, 960),  # back hoof back
        (285, 790),  # back leg knee back
        (295, 720),  # back leg top back
        (390, 760),  # belly back
        (530, 775),  # belly mid
        (640, 755),  # belly front
        (660, 800),  # front leg back knee
        (660, 965),  # back front hoof
        (735, 965),  # front front hoof
        (735, 800),  # front leg front knee
        (745, 730),  # front leg top
        (785, 670),  # chest bottom
        (840, 590),  # throat
        (895, 545),  # jaw corner
        (940, 545),  # snout bottom
    ]
    draw_polygon_with_outline(draw, silhouette, fill=RED, outline_width=12)

    # Dewlap / throat skin (bull trait) - rounded hanging flap
    draw.polygon(
        [(780, 570), (860, 605), (825, 680), (760, 650), (730, 605)],
        fill=OUTLINE,
    )
    draw.polygon(
        [(787, 580), (850, 607), (820, 665), (767, 640), (743, 607)],
        fill=RED_DARK,
    )

    # Body highlights - hard angular muscle lines
    draw.line([(260, 435), (430, 390)], fill=RED_LIGHT, width=12)
    draw.arc([560, 360, 700, 470], start=200, end=310, fill=RED_LIGHT, width=18)
    draw.line([(610, 420), (700, 390)], fill=RED_LIGHT, width=10)

    # Belly shadow
    draw.arc([220, 690, 635, 790], start=200, end=340, fill=RED_DARK, width=16)

    # Near leg muscle highlights
    draw.line([(220, 720), (225, 820)], fill=RED_LIGHT, width=18)
    draw.line([(680, 730), (675, 820)], fill=RED_LIGHT, width=20)

    # Hooves
    for x1, x2 in [(195, 270), (645, 720)]:
        draw.polygon(
            [(x1, 950), (x2, 950), (x2 + 6, 995), (x1 - 6, 995)],
            fill=OUTLINE,
        )

    # Snout / muzzle - red bull nose, small and dark
    draw.ellipse([905, 515, 965, 575], fill=OUTLINE)
    draw.ellipse([910, 520, 960, 570], fill=RED)
    # Single dark bull nose
    draw.ellipse([930, 540, 955, 565], fill=(35, 8, 8))

    # Ear
    draw.polygon([(790, 370), (835, 305), (865, 380)], fill=OUTLINE)
    draw.polygon([(798, 372), (832, 317), (858, 378)], fill=RED_LIGHT)

    # Horns - thicker and more bull-like
    draw_horn(draw, (835, 355), (1005, 235), (1095, 340), 58, 14)
    draw_horn(draw, (775, 370), (925, 250), (1015, 325), 46, 12)

    # Eye - larger and angrier
    eye_cx, eye_cy = 900, 405
    draw.ellipse([eye_cx - 26, eye_cy - 20, eye_cx + 26, eye_cy + 20], fill=OUTLINE)
    draw.ellipse([eye_cx - 19, eye_cy - 13, eye_cx + 19, eye_cy + 13], fill=WHITE)
    draw.ellipse([eye_cx + 3, eye_cy - 7, eye_cx + 17, eye_cy + 7], fill=OUTLINE)
    draw.ellipse([eye_cx + 5, eye_cy - 5, eye_cx + 15, eye_cy + 5], fill=(0, 0, 0))
    # Heavy angry eyebrow
    draw.polygon(
        [(eye_cx - 34, eye_cy - 30), (eye_cx + 38, eye_cy - 40), (eye_cx + 32, eye_cy - 18)],
        fill=OUTLINE,
    )

    # Minimal speed lines
    draw.line([(55, 760), (215, 750)], fill=GOLD, width=6)
    draw.line([(85, 820), (235, 810)], fill=GOLD, width=4)


def draw_money(draw: ImageDraw.ImageDraw) -> None:
    """Draw cartoon dollar money elements around the bull."""
    # Gold coins with $
    draw_coin(draw, 160, 190, 32)
    draw_coin(draw, 880, 170, 26)
    draw_coin(draw, 120, 760, 22)
    # Flying dollar bills
    draw_bill(draw, 220, 270, angle=-18)
    draw_bill(draw, 870, 750, angle=22)
    draw_bill(draw, 115, 620, angle=-32)


def draw_text(img: Image.Image, text: str = "BullNook") -> None:
    """Draw the brand name centered near the bottom."""
    draw = ImageDraw.Draw(img)
    font_size = int(SIZE * 0.072)

    font = None
    for font_path in [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/Library/Fonts/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]:
        try:
            font = ImageFont.truetype(font_path, font_size)
            break
        except OSError:
            continue
    if font is None:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (SIZE - text_width) // 2
    y = int(SIZE * 0.895) - text_height // 2

    outline_range = 3
    for dx in range(-outline_range, outline_range + 1):
        for dy in range(-outline_range, outline_range + 1):
            draw.text((x + dx, y + dy), text, font=font, fill=OUTLINE)
    draw.text((x, y), text, font=font, fill=GOLD)


def main() -> None:
    """Generate and save the icon."""
    img = Image.new("RGB", (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(img)

    draw_background(draw)
    draw_bull(draw)
    draw_money(draw)
    draw_text(img)

    img.save(OUTPUT, "PNG")
    img.save(ASSET, "PNG")
    print(f"Icon saved to {OUTPUT}")
    print(f"Asset updated at {ASSET}")


if __name__ == "__main__":
    main()
