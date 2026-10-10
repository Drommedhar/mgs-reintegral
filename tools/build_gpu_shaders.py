"""Regenerate PsyZ SDL_GPU shader headers with explicitly supplied compilers."""

import argparse
import subprocess
import tempfile
from pathlib import Path


def emit_header(binary: Path, target: Path, symbol: str):
    data = binary.read_bytes()
    rows = [
        "    " + ", ".join(f"0x{byte:02x}" for byte in data[i : i + 12]) + ","
        for i in range(0, len(data), 12)
    ]
    target.write_text(
        "// clang-format off\n"
        f"unsigned char {symbol}[] = {{\n"
        + "\n".join(rows)
        + f"\n}};\nunsigned int {symbol}_len = {len(data)};\n",
        encoding="utf-8",
    )


def compile_shader(args, name: str, temporary: Path):
    stage = name.split(".")[1]
    spirv = temporary / f"{name}.spv"
    subprocess.run(
        [
            args.glslang,
            "-V",
            "--target-env",
            "vulkan1.0",
            "-S",
            stage,
            str(args.source_directory / f"{name}.glsl"),
            "-o",
            str(spirv),
        ],
        check=True,
    )
    metal = temporary / f"{name}.metal"
    hlsl = temporary / f"{name}.hlsl"
    dxil = temporary / f"{name}.dxil"
    subprocess.run(
        [args.spirv_cross, "--msl", str(spirv), "--output", str(metal)], check=True
    )
    subprocess.run(
        [
            args.spirv_cross,
            "--hlsl",
            "--shader-model",
            "60",
            str(spirv),
            "--output",
            str(hlsl),
        ],
        check=True,
    )
    profile = "vs_6_0" if stage == "vert" else "ps_6_0"
    subprocess.run(
        [args.dxc, "-T", profile, "-E", "main", str(hlsl), "-Fo", str(dxil)], check=True
    )
    for suffix, binary in (("spv", spirv), ("msl", metal), ("dxil", dxil)):
        symbol = name.replace(".", "_") + "_" + suffix
        emit_header(binary, args.source_directory / f"{symbol}.h", symbol)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--glslang", required=True)
    parser.add_argument("--spirv-cross", required=True)
    parser.add_argument("--dxc", required=True)
    parser.add_argument(
        "--source-directory",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "vendor/psyz/psyz/src/platform/shaders",
    )
    shaders = ("psx.vert", "psx.frag", "clear.vert", "clear.frag")
    parser.add_argument("--shader", choices=shaders, action="append")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="mgs-shaders-") as temporary:
        for shader in args.shader or shaders:
            compile_shader(args, shader, Path(temporary))


if __name__ == "__main__":
    main()
