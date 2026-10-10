"""Extract Tank camera lifetime code and the real actor scheduler."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output
    root = Path(__file__).resolve().parent.parent / "vendor/mgs/source"
    camera = (root / "overlays/s05a/kojo/m1e1came.c").read_text(encoding="utf-8")
    actor = (root / "libgv/actor.c").read_text(encoding="utf-8")
    snippets = [
        camera[camera.index("typedef struct") : camera.index("extern CamActor")],
        "CamActor *s05a_dword_800C362C;\nCamera *s05a_dword_800C38CC;",
        actor[actor.index("typedef struct") : actor.index("/*----------------")],
    ]
    actor_names = ("GV_InitActorSystem", "GV_InitActor", "GV_SetNamedActor",
                   "GV_DestroyActorQuick", "GV_DestroyActor", "GV_ExecActorSystem")
    snippets.extend(definition(actor, name) for name in actor_names)
    snippets.extend(definition(camera, name) for name in (
        "s05a_ClearTankCameraCallbacks", "s05a_800E1448", "s05a_800E1A68"))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
