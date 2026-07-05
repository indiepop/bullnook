"""Tests for the app icon generator."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from scripts.generate_app_icon import draw_background, draw_bull


ROOT = Path(__file__).resolve().parent.parent


def test_background_size():
    img = draw_background(1024)
    assert img.size == (1024, 1024)
    assert img.mode == "RGBA"


def test_bull_layer():
    bull = draw_bull(1024)
    assert bull.size == (1024, 1024)
    assert bull.mode == "RGBA"
    # There should be non-transparent pixels in the center area
    bbox = bull.getbbox()
    assert bbox is not None


def test_text_present():
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
