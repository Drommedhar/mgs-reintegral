"""Check that the inventory does not turn incomplete evidence into completion."""

import json
import os
import tempfile
import unittest
from pathlib import Path

from jinja2 import Environment
from tools.stage_audit.inventory import (
    compile_evidence,
    overlay_names,
    runtime_evidence,
    selected_objects,
)
from tools.stage_audit.sources import (
    SourceIndex,
    address_evidence,
    c_definitions,
    object_record,
    source_catalog,
)


class StageInventoryTests(unittest.TestCase):
    def test_overlay_comparisons_and_variants(self):
        environment = Environment()
        text = r"""include "MGS_OBJECTS\main.obj"
{% if OVERLAY == "s00a" or OVERLAY in ["s01a", "s02a"] %}
{% if not VR_EXE %}include "MGS_OBJECTS\game.obj"{% endif %}
{% endif %}
{% if VR_EXE and OVERLAY == "sound" %}include "MGS_OBJECTS\sound.obj"{% endif %}
{% if OVERLAY_SUFFIX == "lhs" %}{% endif %}"""
        self.assertEqual(
            overlay_names(environment.parse(text)), ["s00a", "s01a", "s02a", "sound"]
        )
        template = environment.from_string(text)
        self.assertEqual(selected_objects(template, "s01a", False), ["main", "game"])
        self.assertEqual(selected_objects(template, "s01a", True), ["main"])

    def test_present_c_with_assembly_is_not_complete_c(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "source").mkdir()
            (root / "asm").mkdir()
            (root / "source/actor.c").write_text(
                '#pragma INCLUDE_ASM("asm/Actor_800C1234.s")\n'
                '/* #pragma INCLUDE_ASM("asm/ignored.s") */\n'
                'void NewActor(void) { puts("Fake() {"); }\n',
                encoding="utf-8",
            )
            (root / "asm/Actor_800C1234.s").write_text(
                "xdef Actor_800C1234\ndw 0x03E00008 ; 800C1234\n", encoding="utf-8"
            )
            catalog, definitions = source_catalog(root)
            record = object_record(root, "actor", catalog)
            self.assertEqual(record["kind"], "c_with_asm_pragmas")
            self.assertEqual(len(record["assembly"]), 1)
            self.assertIn("NewActor", definitions)
            self.assertNotIn("Fake", definitions)
            self.assertEqual(
                object_record(root, "missing", catalog)["kind"], "missing_source"
            )

    def test_addresses_are_scoped_to_selected_sources(self):
        definitions = {
            "Actor_800C1234": c_definitions(
                "void Actor_800C1234(void) {}", "source/a.c"
            ),
            "Other_800C1234": c_definitions(
                "void Other_800C1234(void) {}", "source/b.c"
            ),
        }
        index = SourceIndex(Path("."), {}, definitions, {}, {})
        evidence = address_evidence("0x800c1234", {"source/a.c"}, index)
        self.assertEqual([item["source"] for item in evidence], ["source/a.c"])

    def test_missing_or_stale_output_is_not_compiled_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            code = source / "actor.c"
            code.write_text("void Actor(void) {}", encoding="utf-8")
            database = root / "compile_commands.json"
            database.write_text(
                json.dumps(
                    [{"file": str(code), "directory": str(root), "output": "actor.obj"}]
                ),
                encoding="utf-8",
            )
            self.assertEqual(
                compile_evidence([database], root, source)["actor.c"][0]["state"],
                "configured_only_or_stale",
            )
            output = root / "actor.obj"
            output.write_bytes(b"object")
            os.utime(output, (1, 1))
            self.assertEqual(
                compile_evidence([database], root, source)["actor.c"][0]["state"],
                "configured_only_or_stale",
            )

    def test_frame_limit_without_movement_is_not_runtime_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "probe.log"
            log.write_text(
                "[probe] PASS completed frame=3600 stage=s00a\n", encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "No completed controller movement"):
                runtime_evidence([log], root)
            with log.open("a", encoding="utf-8") as handle:
                handle.write(
                    "[probe] PASS movement horizontal_delta=431 input_frames=57\n"
                )
            self.assertEqual(
                runtime_evidence([log], root)["s00a"][0]["movement_units"], 431
            )

    def test_generated_source_evidence_keeps_original_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            source = root / "vendor/mgs"
            code = source / "source/actor.c"
            compiled = root / "build/native-source/actor.c"
            code.parent.mkdir(parents=True)
            compiled.parent.mkdir(parents=True)
            code.write_text("void Actor(void) {}", encoding="utf-8")
            compiled.write_text("void Actor(void) {}", encoding="utf-8")
            output = root / "build/actor.obj"
            output.write_bytes(b"object")
            database = root / "build/compile_commands.json"
            database.write_text(
                json.dumps(
                    [
                        {
                            "file": str(compiled),
                            "directory": str(output.parent),
                            "output": output.name,
                        }
                    ]
                ),
                encoding="utf-8",
            )
            evidence = compile_evidence([database], root, source)
            self.assertEqual(
                evidence["source/actor.c"][0]["state"], "object_present_after_source"
            )
            os.utime(code, (output.stat().st_mtime + 10,) * 2)
            self.assertEqual(
                compile_evidence([database], root, source)["source/actor.c"][0][
                    "state"
                ],
                "configured_only_or_stale",
            )

    def test_new_game_trace_does_not_claim_human_playability(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "new-game.log"
            log.write_text(
                "[native] stage=title\n[native] stage=d00a\n[native] stage=s00a\n"
                "[probe] PASS movement horizontal_delta=431 input_frames=237\n"
                "[probe] PASS completed automated input probe frame=6000 stage=s00a\n",
                encoding="utf-8",
            )
            evidence = runtime_evidence([log], root)["s00a"][0]
            self.assertFalse(evidence["human_playability_verified"])
            self.assertEqual(evidence["loaded_stages"], ["title", "d00a", "s00a"])


if __name__ == "__main__":
    unittest.main()
