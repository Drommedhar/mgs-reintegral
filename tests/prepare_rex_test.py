"""Extract the recovered REX helpers unchanged for original-instruction tests."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
HELPERS = (
    "RexNearAngle",
    "RexChoosePatrolWaypoint",
    "RexResumeMotion",
    "RexPauseMotion",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output
    source = ROOT / "vendor/mgs/source"
    text = (source / "kojo/mgrex.c").read_text(encoding="utf-8")
    data = (source / "overlays/s17a/rex_data.c").read_text(encoding="utf-8")
    points = re.search(r"SVECTOR RexPatrolPoints\[14\] = \{.*?\};", data, re.DOTALL)
    if points is None:
        raise ValueError("The original patrol table was not found")
    snippets = [points.group(), *(definition(text, name) for name in HELPERS)]
    particles = (source / "kojo/rex_particles.c").read_text(encoding="utf-8")
    snippets.extend(
        definition(particles, name)
        for name in ("RexSetParticleFrame", "MoveParticle", "RexParticleStep")
    )
    for relative, name in (
        ("libgv/util.c", "GV_AddVec3"),
        ("kojo/mg_laser.c", "RexLaserClip"),
        ("kojo/mg_hatch.c", "RexHatchMove"),
    ):
        snippets.append(
            definition((source / relative).read_text(encoding="utf-8"), name)
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
