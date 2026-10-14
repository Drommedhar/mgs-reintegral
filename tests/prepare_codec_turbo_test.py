"""Extract the actual native Codec decisions for a bounded CPU fixture."""
import argparse
from pathlib import Path


def block(source, marker):
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    source = (root / "vendor/mgs/source/menu/radio.c").read_text(encoding="utf-8")
    helper = block(source, "static int ReiCodecTurboHeld(")
    wait = block(source[source.index("draw_radio_wait_mark(work, ot);"):], "if ((pPad->release &")
    interrupt = block(source, "if (!(pCharaStruct2->field_18 & 1) && ((pPad->release & PAD_CROSS)")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(helper + "\nstatic void Wait(Work *work, Pad *pPad) {\n" + wait +
                          "\n}\nstatic void Interrupt(Work *work, Pad *pPad) {\n"
                          "Chara *pCharaStruct2 = work->field_218;\n" + interrupt + "\n}\n", encoding="utf-8")


if __name__ == "__main__":
    main()
