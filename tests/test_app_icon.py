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
