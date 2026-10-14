"""Require exact VRAM and GPU presentation matches for a paired Legacy fixture."""

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops


def compare(directory: Path):
    reference = (directory / "reference-vram.bin").read_bytes()
    actual = (directory / "godot-vram.bin").read_bytes()
    assert len(reference) == len(actual) == 320 * 240 * 2
    differences = sum(
        reference[offset : offset + 2] != actual[offset : offset + 2]
        for offset in range(0, len(reference), 2)
    )
    expected_image = Image.open(directory / "reference-output.bmp").convert("RGB")
    actual_image = Image.open(directory / "godot-output.png").convert("RGB")
    assert expected_image.size == actual_image.size, (
        "Window sizing changed the capture extent"
    )
    delta = ImageChops.difference(expected_image, actual_image)
    red, green, blue = delta.split()
    maximum = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    image_differences = (
        actual_image.width * actual_image.height - maximum.histogram()[0]
    )
    report = {
        "vram_pixels": 320 * 240,
        "vram_differences": differences,
        "output_size": actual_image.size,
        "output_differences": image_differences,
        "channel_deltas": delta.getextrema(),
    }
    (directory / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    if image_differences:
        delta.save(directory / "difference.png")
    assert differences == image_differences == 0, report
    print("PASS: byte-exact Legacy VRAM and GPU output", actual_image.size)


if __name__ == "__main__":
    compare(Path(sys.argv[1]))
