"""Resolve native translation units from FoxdieTeam's own linker template."""

import argparse
import json
import re
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

try:
    from tools.native_encoding import prepare_sources
    from tools.native_overlay import write_regions
except ModuleNotFoundError:
    from native_encoding import prepare_sources
    from native_overlay import write_regions

SOURCE_ALIASES = {"overlays/s08br/overlay2": "overlays/s08b/overlay2"}


def source_paths(source: Path, stage: str) -> list[Path]:
    environment = Environment(
        loader=FileSystemLoader(source / "build"), autoescape=False
    )
    template = environment.get_template("linker_command_file.txt")
    rendered = template.render(OBJ_DIR="MGS_OBJECTS", PSYQ_SDK="PSYQ", OVERLAY=stage)
    objects = re.findall(
        r'^\s*include "MGS_OBJECTS\\([^"\r\n]+?)\.obj"?', rendered, re.MULTILINE
    )
    identities = [name.replace("\\", "/") for name in objects]
    paths = [
        source / "source" / (SOURCE_ALIASES.get(name, name) + ".c")
        for name in identities
    ]
    return list(dict.fromkeys(paths))


def stage_configuration(path: Path) -> tuple[list[str], dict[str, str]]:
    configuration = json.loads(path.read_text(encoding="utf-8"))
    if configuration.get("version") != 1:
        raise ValueError("Unsupported stage configuration version")
    stages = configuration.get("stages")
    if not isinstance(stages, list) or not stages:
        raise ValueError("Stage configuration requires a nonempty stages list")
    if any(
        not isinstance(stage, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", stage)
        for stage in stages
    ) or len(set(stages)) != len(stages):
        raise ValueError("Stage identities must be unique lowercase identifiers")
    overrides = configuration.get("source_overrides", {})
    if not isinstance(overrides, dict) or any(
        not isinstance(key, str) or not isinstance(value, str)
        for key, value in overrides.items()
    ):
        raise ValueError("Source overrides must map object names to source paths")
    return stages, overrides


def resolve_stages(
    source: Path, project: Path, stages: list[str], overrides: dict[str, str]
) -> tuple[list[Path], dict[str, Path]]:
    paths = []
    tables = {}
    for stage in stages:
        selected = source_paths(source, stage)
        candidates = [path for path in selected if path.parent.name == "stage"]
        if len(candidates) != 1:
            raise ValueError(f"Expected one main-game actor table for {stage}")
        table_text = candidates[0].read_text(encoding="utf-8")
        if re.search(r"\(NEWCHARA\s*\*\)\s*0x[0-9a-fA-F]+", table_text):
            raise ValueError(
                f"Stage {stage} still has unresolved PS1 constructor addresses"
            )
        tables[stage] = candidates[0]
        for path in selected:
            identity = path.relative_to(source / "source").with_suffix("").as_posix()
            if identity in overrides:
                path = (project / overrides[identity]).resolve()
                if not path.is_relative_to(project):
                    raise ValueError(f"Source override escapes project: {identity}")
            if not path.is_file():
                raise ValueError(f"Missing recovered translation unit: {path}")
            if path not in paths:
                paths.append(path)
    return paths, tables


def write_configuration(
    output: Path,
    paths: list[Path],
    tables: dict[str, Path],
    overlay_stages: dict[str, list[Path]] | None = None,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    entries = "\n".join(f'    "{path.as_posix()}"' for path in paths)
    renames = "\n".join(
        f'set_source_files_properties("{path.as_posix()}" PROPERTIES '
        f'COMPILE_DEFINITIONS "_StageCharacterEntries=MgsStageEntries_{path.stem}")'
        for path in dict.fromkeys(tables.values())
    )
    output.write_text(f"set(MGS_SOURCES\n{entries}\n)\n{renames}\n", encoding="utf-8")
    declarations = "\n".join(
        f"extern CHARA MgsStageEntries_{path.stem}[];"
        for path in dict.fromkeys(tables.values())
    )
    registry_entries = []
    for stage, path in tables.items():
        state = (
            f", stage_regions_{stage}, {len(overlay_stages[stage])}"
            if overlay_stages is not None
            else ""
        )
        registry_entries.append(
            f'    {{"{stage}", MgsStageEntries_{path.stem}{state}}},'
        )
    registry = "\n".join(registry_entries)
    output.with_name("mgs_stage_registry.inc").write_text(
        f"{declarations}\nstatic const MgsStageDescriptor stage_registry[] = {{\n"
        f"{registry}\n}};\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--stage")
    parser.add_argument("--config", type=Path)
    args = parser.parse_args()
    if args.stage and args.config:
        parser.error("Choose --stage or --config")
    try:
        stages, overrides = (
            stage_configuration(args.config)
            if args.config
            else ([args.stage or "s00a"], {})
        )
        paths, tables = resolve_stages(
            args.source.resolve(),
            Path(__file__).resolve().parent.parent,
            stages,
            overrides,
        )
        source_root = args.source.resolve() / "source"
        generated_root = args.output.resolve().parent / "native-source"
        resident = set(source_paths(args.source.resolve(), ""))
        overlay_stages = {
            stage: [
                path
                for path in source_paths(args.source.resolve(), stage)
                if path not in resident and path in paths
            ]
            for stage in stages
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        prefixes = write_regions(
            args.output.with_name("mgs_overlay_regions.inc"),
            overlay_stages,
            source_root,
        )
        paths = prepare_sources(source_root, generated_root, paths, prefixes)
        tables = {
            stage: generated_root / path.relative_to(source_root)
            for stage, path in tables.items()
        }
        write_configuration(args.output, paths, tables, overlay_stages)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(
        f"Resolved {len(paths)} native game translation units for {', '.join(stages)}."
    )


if __name__ == "__main__":
    main()
