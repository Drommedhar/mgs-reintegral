"""Stage build manifests must preserve actor-table selection and shared code."""

import tempfile
import unittest
from pathlib import Path

from tools.generate_sources import (
    resolve_stages,
    source_paths,
    stage_configuration,
    write_configuration,
)


class StageSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name).resolve()
        self.source = self.project / "vendor" / "mgs"
        (self.source / "build").mkdir(parents=True)
        (self.source / "source" / "stage").mkdir(parents=True)
        for name in ("common.c", "stage/s00a.c", "stage/s01a.c"):
            (self.source / "source" / name).write_text("", encoding="utf-8")
        (self.source / "build" / "linker_command_file.txt").write_text(
            'include "MGS_OBJECTS\\common.obj"\n'
            'include "MGS_OBJECTS\\stage\\{{OVERLAY}}.obj\n',
            encoding="utf-8",
        )

    def test_shared_sources_once_and_distinct_tables(self):
        paths, tables = resolve_stages(self.source, self.project, ["s00a", "s01a"], {})
        self.assertEqual(len(paths), 3)
        output = self.project / "generated" / "mgs_sources.cmake"
        write_configuration(output, paths, tables)
        cmake = output.read_text(encoding="utf-8")
        registry = output.with_name("mgs_stage_registry.inc").read_text(
            encoding="utf-8"
        )
        self.assertIn("_StageCharacterEntries=MgsStageEntries_s00a", cmake)
        self.assertIn("_StageCharacterEntries=MgsStageEntries_s01a", cmake)
        self.assertIn('{"s00a", MgsStageEntries_s00a}', registry)
        self.assertIn('{"s01a", MgsStageEntries_s01a}', registry)

    def test_missing_source_is_an_error(self):
        (self.source / "source" / "common.c").unlink()
        with self.assertRaisesRegex(ValueError, "Missing recovered"):
            resolve_stages(self.source, self.project, ["s00a"], {})

    def test_ninja_variant_uses_canonical_data_for_compile_and_state_reset(self):
        (self.source / "build" / "linker_command_file.txt").write_text(
            'include "MGS_OBJECTS\\overlays\\{{OVERLAY}}\\overlay2.obj"\n',
            encoding="utf-8",
        )
        expected = self.source / "source/overlays/s08b/overlay2.c"
        self.assertEqual(source_paths(self.source, "s08b"), [expected])
        self.assertEqual(source_paths(self.source, "s08br"), [expected])

    def test_ps1_constructor_addresses_cannot_enter_native_registry(self):
        (self.source / "source" / "stage" / "s00a.c").write_text(
            "CHARA entries[] = {{0x1234, (NEWCHARA *)0x800d0000}};", encoding="utf-8"
        )
        with self.assertRaisesRegex(ValueError, "unresolved PS1 constructor"):
            resolve_stages(self.source, self.project, ["s00a"], {})

    def test_stage_alias_uses_one_compiled_actor_table(self):
        (self.source / "build" / "linker_command_file.txt").write_text(
            'include "MGS_OBJECTS\\stage\\s00a.obj"\n', encoding="utf-8"
        )
        paths, tables = resolve_stages(self.source, self.project, ["s00a", "s02e"], {})
        output = self.project / "aliases.cmake"
        write_configuration(output, paths, tables)
        self.assertEqual(len(paths), 1)
        self.assertEqual(
            output.read_text(encoding="utf-8").count("set_source_files_properties"), 1
        )
        registry = output.with_name("mgs_stage_registry.inc").read_text(
            encoding="utf-8"
        )
        self.assertEqual(registry.count("extern CHARA"), 1)
        self.assertIn('{"s02e", MgsStageEntries_s00a}', registry)

    def test_explicit_native_source_override(self):
        (self.source / "source" / "common.c").unlink()
        replacement = self.project / "replacement.c"
        replacement.write_text("", encoding="utf-8")
        paths, _ = resolve_stages(
            self.source, self.project, ["s00a"], {"common": "replacement.c"}
        )
        self.assertEqual(paths[0], replacement)

    def test_override_cannot_escape_project(self):
        with self.assertRaisesRegex(ValueError, "escapes project"):
            resolve_stages(
                self.source, self.project, ["s00a"], {"common": "../outside.c"}
            )

    def test_stage_list_rejects_ambiguous_identities(self):
        configuration = self.project / "stages.json"
        for stages in ("[]", '["s00a", "s00a"]', '["../s00a"]'):
            configuration.write_text(
                '{"version":1,"stages":' + stages + "}", encoding="utf-8"
            )
            with self.assertRaises(ValueError):
                stage_configuration(configuration)


if __name__ == "__main__":
    unittest.main()
