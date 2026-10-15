"""Pack Irbif's pixel animation without changing its authored pixels or timing."""

import argparse
import hashlib
from pathlib import Path

from PIL import Image

SOURCE_SHA256 = "045c6aa4a4f7713b3b94b0f497fc30387857169af2337c87146ce88de00331fe"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if hashlib.sha256(args.source.read_bytes()).hexdigest() != SOURCE_SHA256:
        parser.error("Source differs from the pinned Irbif animation")
    atlas = Image.new("RGBA", (640, 350))
    with Image.open(args.source) as source:
        if source.size != (1600, 1400) or source.n_frames != 37:
            parser.error("Unexpected animation dimensions or frame count")
        for index in range(source.n_frames):
            source.seek(index)
            original = source.convert("RGBA")
            pixels = original.resize((80, 70), Image.Resampling.NEAREST)
            if (
                pixels.resize(source.size, Image.Resampling.NEAREST).tobytes()
                != original.tobytes()
            ):
                parser.error(f"Frame {index} is not an exact 20x pixel enlargement")
            if source.info.get("duration") != 100:
                parser.error(f"Unexpected timing at frame {index}")
            atlas.paste(pixels, (index % 8 * 80, index // 8 * 70))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output)
    print(hashlib.sha256(args.output.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
