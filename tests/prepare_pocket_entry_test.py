"""Extract the live PocketStation entry state machine and its keyboard tables."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
ENTRY = ROOT / "vendor/mgs/source/overlays/rank/chara/pocket/entry.c"
DATA = ROOT / "vendor/mgs/source/overlays/rank/overlay2.c"


def table(source, name):
    match = re.search(
        r"^[\w \t*]+\b" + re.escape(name) + r"\[[^;]+?;",
        source,
        re.MULTILINE | re.DOTALL,
    )
    if match is None:
        raise ValueError(f"Missing PocketStation data: {name}")
    return match.group()


def state_source():
    source = ENTRY.read_text(encoding="utf-8")
    state = ENTRY.with_name("entry_state.c").read_text(encoding="utf-8")
    data = DATA.read_text(encoding="utf-8")
    keys = table(data, "PocketKeys")
    strings = sorted(set(re.findall(r"PocketString_[0-9A-F]+", keys)))
    pieces = [table(data, name) for name in strings]
    pieces += [
        keys,
        table(data, "PocketCharacterMap"),
        definition(source, "rank_800D2888"),
    ]
    names = (
        "PocketPhase",
        "PocketFinish",
        "PocketDevicePhase",
        "PocketChoice",
        "PocketIntro",
        "PocketPrompt",
        "PocketShowKeyboard",
        "PocketSelectKey",
        "PocketSpecialKey",
        "PocketTypeKey",
        "PocketKeyboard",
        "PocketReturnToKeyboard",
        "PocketConfirm",
        "PocketCancel",
        "PocketDrawName",
        "rank_800D28D4",
    )
    pieces.extend(definition(state, name) for name in names)
    return "\n\n".join(pieces) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(state_source(), encoding="utf-8")


if __name__ == "__main__":
    main()
