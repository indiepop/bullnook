"""Tests for the app icon generator."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

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
