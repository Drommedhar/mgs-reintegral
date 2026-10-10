"""Preserve the original EUC-JP literal bytes with a UTF-8-only host compiler."""

import re
from pathlib import Path

C_TOKEN = re.compile(
    r"(?P<comment>//(?:\\\r?\n|[^\n])*|/\*[\s\S]*?\*/)"
    r'|(?P<literal>(?:u8|[LuU])?(?:"(?:\\[\s\S]|[^"\\])*"|\'(?:\\[\s\S]|[^\'\\])*\'))'
)


def encode_literals(contents: str) -> str:
    def convert(match: re.Match[str]) -> str:
        token = match.group()
        if match.group("comment") or token.isascii():
            return token
        if token.startswith(("L", "u", "U")):
            raise ValueError(
                "Non-ASCII wide/UTF string literals need an explicit native implementation"
            )
        return "".join(
            character
            if ord(character) < 128
            else "".join(f"\\{byte:03o}" for byte in character.encode("euc_jp"))
            for character in token
        )

    return C_TOKEN.sub(convert, contents)


def write_if_changed(path: Path, contents: str) -> None:
    if path.is_file() and path.read_text(encoding="utf-8") == contents:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8", newline="\n")


def prepare_sources(
    source_root: Path,
    output_root: Path,
    paths: list[Path],
    prefixes: dict[Path, str] | None = None,
) -> list[Path]:
    selected = [path for path in paths if path.is_relative_to(source_root)]
    headers = sorted([*source_root.rglob("*.h"), *source_root.rglob("*.cnf")])
    for path in dict.fromkeys([*selected, *headers]):
        contents = encode_literals(path.read_text(encoding="utf-8"))
        filename = path.as_posix().replace('"', '\\"')
        write_if_changed(
            output_root / path.relative_to(source_root),
            (prefixes or {}).get(path, "") + f'#line 1 "{filename}"\n{contents}',
        )
    return [
        output_root / path.relative_to(source_root)
        if path.is_relative_to(source_root)
        else path
        for path in paths
    ]
