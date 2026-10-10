"""Extract the actual equipped-camera encoder for original-instruction checks."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (ROOT / "vendor/mgs/source/equip/jpegcam.c").read_text(encoding="utf-8")
    work_start = source.index("typedef struct _Work")
    work_end = source.index("} Work;", work_start) + len("} Work;")
    tables_start = source.index("STATIC signed char gJpegcamZigZagTable")
    tables_end = source.index("STATIC SVECTOR dword_8009F3AC", tables_start)
    snippets = [
        "typedef signed char TMat8x8B[8][8];",
        "typedef signed char TMat16x16B[16][16];",
        "typedef int TMat8x8I[8][8];",
        "static TMat8x8B gJpegcamMatrix2_800BDCD8;",
        source[work_start:work_end],
        source[tables_start:tables_end],
    ]
    names = [
        "JpegInitMatrix",
        "JpegColorCvt_XBGR1555_to_BGRX8888",
        "JpegMacroblock_RGB_to_YUV",
        "JpegSplitLumaBlocks",
        "JpegDownsampleChroma420",
        "JpegApplyDCT",
        "JpegQuantizeZigzagMatrix",
        "JpegRLEStream",
        "JpegCompressMacroblock",
    ]
    snippets.extend(definition(source, name) for name in names)
    snippets.append(
        source[
            source.index("#define ROUND") : source.index("static int JpegCompressFrame")
        ]
    )
    snippets.extend(
        definition(source, name)
        for name in ("JpegCompressFrame", "JpegTryCompressFrame")
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
