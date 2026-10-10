"""Give each recovered overlay translation unit a resettable COFF data range."""

import hashlib
from pathlib import Path


def region_id(path: Path, source_root: Path) -> str:
    identity = path.relative_to(source_root).as_posix()
    return hashlib.sha256(identity.encode("utf-8")).hexdigest()[:12]


def region_prefix(identity: str) -> str:
    section = f".mgsst${identity}"
    symbol = f"MgsOverlay_{identity}"
    # Leave the pragmas active through EOF: C tentative definitions are emitted
    # after parsing and otherwise escape to the default BSS section with Clang.
    return (
        f'#pragma section("{section}$a", read, write)\n'
        f'#pragma section("{section}$z", read, write)\n'
        f'__declspec(allocate("{section}$a")) unsigned char {symbol}_begin = 0;\n'
        f'__declspec(allocate("{section}$z")) unsigned char {symbol}_end = 0;\n'
        f'#pragma data_seg("{section}$m")\n'
        f'#pragma bss_seg("{section}$n")\n'
    )


def write_regions(output: Path, stages: dict[str, list[Path]], source_root: Path):
    paths = list(
        dict.fromkeys(path for selected in stages.values() for path in selected)
    )
    identities = {path: region_id(path, source_root) for path in paths}
    if len(set(identities.values())) != len(paths):
        raise ValueError("Overlay section identity collision")
    declarations = "\n".join(
        f"extern unsigned char MgsOverlay_{identity}_begin, MgsOverlay_{identity}_end;"
        for identity in identities.values()
    )
    regions = "\n".join(
        f'    {{"{path.relative_to(source_root).as_posix()}", '
        f"&MgsOverlay_{identity}_begin, &MgsOverlay_{identity}_end, NULL}},"
        for path, identity in identities.items()
    )
    indices = {path: index for index, path in enumerate(paths)}
    stage_lists = "\n".join(
        f"static const size_t stage_regions_{stage}[] = {{"
        + ", ".join(str(indices[path]) for path in selected)
        + "};"
        for stage, selected in stages.items()
    )
    output.write_text(
        f"{declarations}\nstatic MgsOverlayRegion overlay_regions[] = {{\n{regions}\n}};\n"
        f"{stage_lists}\n",
        encoding="utf-8",
    )
    return {path: region_prefix(identity) for path, identity in identities.items()}
