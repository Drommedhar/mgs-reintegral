"""Index recovered C, MIPS assembly, and stage constructor evidence."""

import hashlib
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

ASM_PRAGMA = re.compile(r'#pragma\s+INCLUDE_ASM\s*\(\s*"([^"]+)"\s*\)')


FUNCTION = re.compile(r"\b([A-Za-z_]\w*)\s*\((?:[^(){};]|\([^(){};]*\))*\)\s*\{")


RAW_CONSTRUCTOR = re.compile(
    r"\{\s*(0x[0-9a-fA-F]+)\s*,\s*\(NEWCHARA\s*\*\)\s*(0x[0-9a-fA-F]+)\s*\}"
)


MACRO = re.compile(
    r"^#define\s+((?:CHARA|DEMO)_\w+)\s+\{\s*(0x[0-9a-fA-F]+)\s*,\s*([^}]+)\}",
    re.MULTILINE,
)


COMMENT_OR_STRING = re.compile(
    r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', re.DOTALL
)


@dataclass
class SourceIndex:
    root: Path
    catalog: dict
    definitions: dict
    macros: dict
    address_symbols: dict


def without_comments(text: str, remove_strings: bool = False) -> str:
    def replace(match: re.Match) -> str:
        value = match.group()
        return (
            re.sub(r"[^\n]", " ", value)
            if remove_strings or value.startswith("/")
            else value
        )

    return COMMENT_OR_STRING.sub(replace, text)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def assembly_record(source: Path, name: str) -> dict:
    path = source / name
    result = {"path": name, "exists": path.is_file()}
    if not path.is_file():
        return result
    text = path.read_text(encoding="utf-8")
    symbols = re.findall(r"^\s*xdef\s+(\w+)", text, re.MULTILINE)
    address = re.search(r"_([0-9A-Fa-f]{8})$", path.stem)
    result.update(
        symbols=symbols,
        instruction_words=len(re.findall(r"^\s*dw\s+", text, re.MULTILINE)),
    )
    if address:
        result["address"] = f"0x{int(address[1], 16):08x}"
    return result


def c_definitions(text: str, path: str) -> list[dict]:
    definitions = []
    for match in FUNCTION.finditer(without_comments(text, remove_strings=True)):
        symbol = match[1]
        if symbol in {"if", "for", "while", "switch"}:
            continue
        definitions.append(
            {
                "symbol": symbol,
                "source": path,
                "line": text.count("\n", 0, match.start()) + 1,
            }
        )
    return definitions


def source_catalog(source: Path) -> tuple[dict, dict]:
    records = {}
    definitions = defaultdict(list)
    for path in sorted((source / "source").rglob("*.c")):
        name = relative(path, source)
        text = path.read_text(encoding="utf-8")
        code = without_comments(text)
        assembly = [assembly_record(source, item) for item in ASM_PRAGMA.findall(code)]
        records[name] = {
            "kind": "c_with_asm_pragmas" if assembly else "c_without_asm_pragmas",
            "sha256": digest(path),
            "assembly": assembly,
            "inline_asm_sites": len(re.findall(r"\b(?:asm|__asm__)\s*\(", code)),
        }
        for definition in c_definitions(text, name):
            definitions[definition["symbol"]].append(definition)
    return records, dict(definitions)


def object_record(source: Path, name: str, catalog: dict) -> dict:
    c_path = f"source/{name}.c"
    if c_path in catalog:
        return {"source": c_path, **catalog[c_path]}
    assembly = assembly_record(source, f"asm/{name}.s")
    return {
        "source": c_path,
        "kind": "assembly_only" if assembly["exists"] else "missing_source",
        "assembly": [assembly] if assembly["exists"] else [],
    }


def character_macros(source: Path) -> dict:
    text = (source / "source/include/charalst.h").read_text(encoding="utf-8")
    return {
        name: {"class_id": f"0x{int(identity, 16):04x}", "symbol": symbol.strip()}
        for name, identity, symbol in MACRO.findall(text)
    }


def resident_symbols(source: Path) -> dict:
    symbols = {}
    text = (source / "build/functions.txt").read_text(encoding="utf-8")
    for line in text.splitlines():
        address, size, name = line.split()
        symbols[f"0x{int(address, 16):08x}"] = {
            "symbol": name,
            "size": int(size),
            "map": "build/functions.txt",
        }
    return symbols


def macro_candidates(
    identity: str, line: str, macros: dict, definitions: dict, selection: set
) -> list[dict]:
    hinted = re.findall(r"\b(?:CHARA|DEMO)_\w+\b", line)
    names = hinted or [
        name for name, value in macros.items() if value["class_id"] == identity
    ]
    candidates = []
    for name in names:
        value = macros.get(name)
        if value is None or value["class_id"] != identity:
            continue
        locations = definitions.get(value["symbol"], [])
        candidates.append(
            {
                "macro": name,
                "symbol": value["symbol"],
                "evidence": "class_id_and_comment" if hinted else "class_id_only",
                "definitions": locations,
                "defined_in_selection": any(
                    item["source"] in selection for item in locations
                ),
            }
        )
    return candidates


def address_evidence(address: str, selection: set, source: SourceIndex) -> list[dict]:
    matches = []
    suffix = address[2:].lower()
    for symbol, locations in source.definitions.items():
        if symbol.lower().endswith("_" + suffix):
            matches.extend(
                {"kind": "c_symbol_suffix", **item}
                for item in locations
                if item["source"] in selection
            )
    for name in selection:
        record = source.catalog.get(name)
        if record is None:
            continue
        for assembly in record["assembly"]:
            if assembly.get("address") == address:
                matches.append({"kind": "selected_assembly", **assembly})
    if address in source.address_symbols:
        matches.append(
            {"kind": "resident_symbol_map", **source.address_symbols[address]}
        )
    return matches


def stage_constructors(source: SourceIndex, tables: list[str], selection: set) -> dict:
    raw = []
    named = []
    for table in tables:
        text = (source.root / table).read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), 1):
            match = RAW_CONSTRUCTOR.search(without_comments(line))
            if match:
                identity, address = (
                    f"0x{int(match[1], 16):04x}",
                    f"0x{int(match[2], 16):08x}",
                )
                raw.append(
                    {
                        "table": table,
                        "line": number,
                        "class_id": identity,
                        "address": address,
                        "candidates": macro_candidates(
                            identity, line, source.macros, source.definitions, selection
                        ),
                        "address_evidence": address_evidence(
                            address, selection, source
                        ),
                        "requires_binary_confirmation": True,
                    }
                )
            named.extend(
                re.findall(r"^\s*((?:CHARA|DEMO)_\w+)\s*,", without_comments(line))
            )
    return {"tables": tables, "named_entries": named, "raw_entries": raw}
