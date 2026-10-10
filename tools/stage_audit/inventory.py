"""Build a stage inventory from source, compile artifacts, and probe logs."""

import argparse
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, nodes

from .sources import (
    SourceIndex,
    character_macros,
    digest,
    object_record,
    relative,
    resident_symbols,
    source_catalog,
    stage_constructors,
)

INCLUDE = re.compile(r'^\s*include "MGS_OBJECTS\\([^"\r\n]+?)\.obj"?', re.MULTILINE)


@dataclass
class AuditContext:
    source: SourceIndex
    template: object
    tree: nodes.Template
    compiled: dict
    runtime: dict


def overlay_names(tree: nodes.Template) -> list[str]:
    names = set()
    for comparison in tree.find_all(nodes.Compare):
        if not isinstance(comparison.expr, nodes.Name):
            continue
        if comparison.expr.name != "OVERLAY":
            continue
        for operand in comparison.ops:
            values = (
                operand.expr.items
                if isinstance(operand.expr, nodes.List)
                else [operand.expr]
            )
            names.update(
                value.value for value in values if isinstance(value, nodes.Const)
            )
    return sorted(names)


def selected_objects(template, overlay: str, vr: bool) -> list[str]:
    rendered = template.render(
        OBJ_DIR="MGS_OBJECTS",
        PSYQ_SDK="PSYQ",
        OVERLAY=overlay,
        OVERLAY_SUFFIX="lhs",
        VR_EXE=vr,
        INTEGRAL=True,
    )
    return list(
        dict.fromkeys(name.replace("\\", "/") for name in INCLUDE.findall(rendered))
    )


def compile_evidence(paths: list[Path], project: Path, source: Path) -> dict:
    source = source.resolve()
    evidence = defaultdict(list)
    for database in paths:
        entries = json.loads(database.read_text(encoding="utf-8"))
        for entry in entries:
            path = Path(entry["file"]).resolve()
            compiled_path = path
            mirror = database.resolve().parent / "native-source"
            if path.is_relative_to(mirror):
                path = source / "source" / path.relative_to(mirror)
            if not path.is_relative_to(source):
                continue
            output = Path(entry["directory"]) / entry["output"]
            current = (
                output.is_file()
                and path.is_file()
                and compiled_path.is_file()
                and output.stat().st_mtime_ns
                >= max(path.stat().st_mtime_ns, compiled_path.stat().st_mtime_ns)
            )
            evidence[relative(path, source)].append(
                {
                    "database": relative(database, project),
                    "object": relative(output, project),
                    "state": "object_present_after_source"
                    if current
                    else "configured_only_or_stale",
                }
            )
    return dict(evidence)


def runtime_evidence(paths: list[Path], project: Path) -> dict:
    evidence = defaultdict(list)
    for path in paths:
        text = path.read_text(encoding="utf-8")
        completed = re.search(
            r"\[probe\] PASS completed(?: automated input probe)? frame=(\d+) stage=(\w+)",
            text,
        )
        movement = re.search(
            r"\[probe\] PASS movement.*horizontal_delta=(\d+) input_frames=(\d+)", text
        )
        if not completed or not movement:
            raise ValueError(f"No completed controller movement probe in {path}")
        evidence[completed[2]].append(
            {
                "log": relative(path, project),
                "sha256": digest(path),
                "frames": int(completed[1]),
                "movement_units": int(movement[1]),
                "input_frames": int(movement[2]),
                "method": "automated_virtual_controller",
                "human_playability_verified": False,
                "loaded_stages": re.findall(r"\[native\] stage=(\w+)", text),
            }
        )
    return dict(evidence)


def stage_names(source: Path, tree: nodes.Template, vr: bool) -> list[str]:
    folder = "stagevr" if vr else "stage"
    names = {
        path.stem
        for path in (source / "source" / folder).glob("*.c")
        if not path.stem.startswith("_")
    }
    names.update(path.stem for path in (source / "um" / folder).glob("*.bin"))
    if not vr:
        names.update(overlay_names(tree))
    return sorted(names)


def stage_record(
    context: AuditContext, name: str, vr: bool, base: list[str], objects: dict
) -> dict:
    source = context.source
    selection = selected_objects(context.template, name, vr)
    additional = [item for item in selection if item not in base]
    configured = bool(additional)
    objects.update(
        (item, object_record(source.root, item, source.catalog)) for item in selection
    )
    paths = {objects[item]["source"] for item in selection}
    folder = "stagevr" if vr else "stage"
    tables = sorted(path for path in paths if path.startswith(f"source/{folder}/"))
    unmatched = f"source/{folder}/{name}.c"
    if not tables and (source.root / unmatched).is_file():
        tables = [unmatched]
    constructors = stage_constructors(source, tables, paths)
    native = [
        path
        for path in paths
        if any(
            item["state"] == "object_present_after_source"
            for item in context.compiled.get(path, [])
        )
    ]
    return {
        "name": name,
        "variant": "vr" if vr else "main",
        "linker_selection": "configured" if configured else "absent",
        "objects": selection if configured else [],
        "overlay_objects": additional,
        "object_kinds": dict(
            sorted(Counter(objects[item]["kind"] for item in additional).items())
        ),
        "constructors": constructors,
        "native": {
            "observed_objects": len(native) if configured else 0,
            "required_objects": len(selection) if configured else None,
            "all_objects_observed": configured and len(native) == len(selection),
        },
        "runtime": {
            "state": "controller_probe_passed"
            if not vr and name in context.runtime
            else "not_observed",
            "evidence": context.runtime.get(name, []) if not vr else [],
        },
    }


def stage_inventory(context: AuditContext, vr: bool) -> tuple[list[dict], dict]:
    base = selected_objects(context.template, "", vr)
    objects = {}
    stages = [
        stage_record(context, name, vr, base, objects)
        for name in stage_names(context.source.root, context.tree, vr)
    ]
    return stages, objects


def inventory(args: argparse.Namespace) -> dict:
    source, project = args.source.resolve(), args.project.resolve()
    environment = Environment(
        loader=FileSystemLoader(source / "build"), autoescape=False
    )
    template_path = source / "build/linker_command_file.txt"
    tree = environment.parse(template_path.read_text(encoding="utf-8"))
    template = environment.get_template(template_path.name)
    catalog, definitions = source_catalog(source)
    compiled = compile_evidence(args.compile_commands, project, source)
    runtime = runtime_evidence(args.runtime_log, project)
    index = SourceIndex(
        source, catalog, definitions, character_macros(source), resident_symbols(source)
    )
    context = AuditContext(index, template, tree, compiled, runtime)
    stages, objects = [], {}
    for vr in (False, True):
        variant_stages, variant_objects = stage_inventory(context, vr)
        stages.extend(variant_stages)
        objects.update(variant_objects)
    for item in objects.values():
        item["native_evidence"] = compiled.get(item["source"], [])
    lock = json.loads((project / "sources.lock.json").read_text(encoding="utf-8"))
    pin = next(
        repo["commit"] for repo in lock["repositories"] if repo["path"] == "vendor/mgs"
    )
    return {
        "schema_version": 1,
        "upstream_commit": pin,
        "template_sha256": digest(template_path),
        "definitions": {
            "c_without_asm_pragmas": "C file exists with no textual INCLUDE_ASM pragma; not proof of correctness or portability.",
            "native_observed": "Compile database output exists and is no older than its C source; headers, successful linking and runtime are separate evidence.",
            "constructor_candidates": "Class identifiers, comments and selected C/assembly symbols are recovery leads, not verified address bindings.",
            "scope": "Main and VR stage tables, uninitialized-memory manifest names, and every OVERLAY comparison in the linker template; no retail bytes are read or emitted.",
        },
        "summary": {
            "stage_records": len(stages),
            "objects": len(objects),
            "configured_main_stages": sum(
                item["variant"] == "main" and item["linker_selection"] == "configured"
                for item in stages
            ),
            "raw_constructor_entries": sum(
                len(item["constructors"]["raw_entries"]) for item in stages
            ),
        },
        "objects": dict(sorted(objects.items())),
        "stages": stages,
    }
