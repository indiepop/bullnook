# Golden Bull App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a 1024×1024 golden bull app icon PNG for BullNook using Python Pillow, replacing the existing abstract horn icon.

**Architecture:** A single Python script `scripts/generate_app_icon.py` draws the icon in layers: radial golden background, bronze bull silhouette in side-profile looking back, metallic highlights, shadow, and "BullNook" text. A small test file verifies output dimensions and color mode.

**Tech Stack:** Python 3, Pillow 11.x

## Global Constraints

- Output size: 1024 × 1024 px.
- Background: golden radial gradient centered, light gold `#FFD700` to bronze `#B8860B` → `#8B6914`.
- Bull: side-profile looking back, dark bronze with metallic gold highlights.
- Text: "BullNook" in light gold `#FFF8DC` at the bottom.
- Keep the script under version control; output PNG replaces `app_icon_1024.png`.

---

## File Structure

- `scripts/generate_app_icon.py` — icon generation script.
- `tests/test_app_icon.py` — verifies the generated PNG.
- `app_icon_1024.png` — final icon (overwrites existing untracked file).
- `app_icon_1024_horn.png` — backup of the old abstract horn icon (created if not present).

---

### Task 1: Bootstrap script and draw radial golden background

**Files:**
- Create: `scripts/generate_app_icon.py`
- Create: `tests/test_app_icon.py`

**Interfaces:**
- Produces: `draw_background(size) -> Image.Image` returning a 1024×1024 RGBA image with the radial gradient.

- [ ] **Step 1: Create the generation script with a background helper**

Create `scripts/generate_app_icon.py`:

```python
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
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    center = size // 2
    max_radius = int((size * 0.75))

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

    # Fill outer corners with dark bronze
    draw.ellipse([0, 0, size - 1, size - 1], outline=DARK_BRONZE + (255,))
    return img


if __name__ == "__main__":
    icon = draw_background()
    icon.save(ROOT / "app_icon_1024.png")
```

- [ ] **Step 2: Add a test for background dimensions**

Create `tests/test_app_icon.py`:

```python
"""Tests for the app icon generator."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from scripts.generate_app_icon import draw_background


ROOT = Path(__file__).resolve().parent.parent


def test_background_size():
    img = draw_background(1024)
    assert img.size == (1024, 1024)
    assert img.mode == "RGBA"
```

- [ ] **Step 3: Run the test**

Run:

```bash
python3 -m pytest tests/test_app_icon.py -v
```

Expected: `test_background_size` passes.

- [ ] **Step 4: Generate a preview and inspect**

Run:

```bash
python3 scripts/generate_app_icon.py
```

Expected: `app_icon_1024.png` is created/overwritten with a golden radial gradient.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_app_icon.py tests/test_app_icon.py
git commit -m "feat(icon): add golden radial background generator"
```

---

### Task 2: Draw the side-profile golden bull

**Files:**
- Modify: `scripts/generate_app_icon.py`
- Modify: `tests/test_app_icon.py`

**Interfaces:**
- Produces: `draw_bull(img: Image.Image) -> Image.Image` that composites the bull onto the background.

- [ ] **Step 1: Add bull shape helper functions**

Append to `scripts/generate_app_icon.py`:

```python
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

    # Create gradient layer
    grad = Image.new("RGBA", img.size, base_color + (255,))
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
```

- [ ] **Step 2: Composite the bull onto the background**

Modify the `__main__` block in `scripts/generate_app_icon.py`:

```python
def compose_icon(size: int = SIZE) -> Image.Image:
    """Compose background + bull into the final icon."""
    icon = draw_background(size)
    bull = draw_bull(size)
    icon.alpha_composite(bull)
    return icon


if __name__ == "__main__":
    icon = compose_icon()
    icon.save(ROOT / "app_icon_1024.png")
```

- [ ] **Step 3: Add a test for the bull layer**

Append to `tests/test_app_icon.py`:

```python
def test_bull_layer():
    bull = draw_bull(1024)
    assert bull.size == (1024, 1024)
    assert bull.mode == "RGBA"
    # There should be non-transparent pixels in the center area
    bbox = bull.getbbox()
    assert bbox is not None
```

- [ ] **Step 4: Run tests and regenerate preview**

Run:

```bash
python3 -m pytest tests/test_app_icon.py -v
python3 scripts/generate_app_icon.py
```

Expected: tests pass and `app_icon_1024.png` now shows the golden background plus a bronze bull silhouette.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_app_icon.py tests/test_app_icon.py app_icon_1024.png
git commit -m "feat(icon): add side-profile bronze bull with metallic gradient"
```

---

### Task 3: Add the "BullNook" brand text

**Files:**
- Modify: `scripts/generate_app_icon.py`
- Modify: `tests/test_app_icon.py`

**Interfaces:**
- Produces: `draw_text(img: Image.Image) -> Image.Image` that composites "BullNook" at the bottom.

- [ ] **Step 1: Add text drawing helper**

Append to `scripts/generate_app_icon.py`:

```python
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
```

- [ ] **Step 2: Update composition to include text**

Modify `compose_icon`:

```python
def compose_icon(size: int = SIZE) -> Image.Image:
    """Compose background + bull + text into the final icon."""
    icon = draw_background(size)
    bull = draw_bull(size)
    icon.alpha_composite(bull)
    icon = draw_text(icon)
    return icon
```

- [ ] **Step 3: Add a test for text presence**

Append to `tests/test_app_icon.py`:

```python
def test_text_present():
    from PIL import ImageFont

    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    font_size = 92
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except OSError:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", font_size)
        except OSError:
            font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), "BullNook", font=font)
    assert bbox[2] - bbox[0] > 0
    assert bbox[3] - bbox[1] > 0
```

- [ ] **Step 4: Run tests and regenerate preview**

Run:

```bash
python3 -m pytest tests/test_app_icon.py -v
python3 scripts/generate_app_icon.py
```

Expected: tests pass and `app_icon_1024.png` shows the bull with "BullNook" text below it.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_app_icon.py tests/test_app_icon.py app_icon_1024.png
git commit -m "feat(icon): add BullNook brand text"
```

---

### Task 4: Polish, backup old icon, and final verification

**Files:**
- Modify: `scripts/generate_app_icon.py`
- Modify: `app_icon_1024.png`
- Create: `app_icon_1024_horn.png` (backup of old icon, if it exists)

- [ ] **Step 1: Backup the old abstract horn icon**

Before overwriting, if an old icon exists and a backup does not, copy it:

Add at the top of the `__main__` block in `scripts/generate_app_icon.py`:

```python
if __name__ == "__main__":
    old_icon = ROOT / "app_icon_1024.png"
    backup = ROOT / "app_icon_1024_horn.png"
    if old_icon.exists() and not backup.exists():
        old_icon.rename(backup)

    icon = compose_icon()
    icon.save(ROOT / "app_icon_1024.png")
```

- [ ] **Step 2: Add final preview/test**

Append to `tests/test_app_icon.py`:

```python
def test_final_icon():
    output = ROOT / "app_icon_1024.png"
    assert output.exists()
    img = Image.open(output)
    assert img.size == (1024, 1024)
    assert img.mode in ("RGB", "RGBA")
```

- [ ] **Step 3: Run full test suite and regenerate final icon**

Run:

```bash
python3 -m pytest tests/test_app_icon.py -v
python3 scripts/generate_app_icon.py
```

Expected:
- `app_icon_1024_horn.png` is created from the previous icon.
- `app_icon_1024.png` is the new golden bull icon.
- All tests pass.

- [ ] **Step 4: Inspect the final PNG**

Open `app_icon_1024.png` to visually confirm:
- Golden radial background.
- Bronze bull in side profile looking back.
- "BullNook" text readable at the bottom.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_app_icon.py tests/test_app_icon.py app_icon_1024.png app_icon_1024_horn.png
git commit -m "feat(icon): finalize golden bull app icon and backup old horn icon"
```

---

## Self-Review

**Spec coverage:**
- 1024×1024 PNG output → Task 4 Step 3.
- Golden radial background → Task 1.
- Side-profile bull looking back → Task 2.
- Metallic highlights → `draw_polygon_gradient` in Task 2.
- "BullNook" text → Task 3.
- Backup old icon → Task 4 Step 1.

**Placeholder scan:** No TBD/TODO; all steps include concrete code and commands.

**Type consistency:** `draw_background`, `draw_bull`, `draw_text`, and `compose_icon` all operate on `PIL.Image.Image` and use consistent `tuple[int, int, int]` color tuples.

**Gaps:** None identified.
