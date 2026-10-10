"""Check the real movie adapter in separate processes with engine boundary doubles."""

import argparse
import subprocess
import tempfile
from pathlib import Path


def check_output(mode: str, output: str, code: int, expected: int) -> None:
    if code != expected:
        raise AssertionError(f"{mode}: exit {code}, expected {expected}\n{output}")
    if mode == "unknown":
        if "Unknown input movie test case" not in output:
            raise AssertionError(output)
        return
    if f"TESTCASE_OK {mode} " not in output:
        raise AssertionError(f"{mode}: checks did not complete\n{output}")
    if ("[input] PASS replay" in output) != (mode == "normal"):
        raise AssertionError(f"{mode}: incorrect replay success claim\n{output}")
    diagnostic = mode in ("tail1", "tail3", "early")
    if ("[input] DIAGNOSTIC:" in output) != diagnostic:
        raise AssertionError(f"{mode}: incorrect diagnostic transition\n{output}")
    if diagnostic and (
        "verified prefix through 2 samples/2 VSyncs" not in output
        or "completion remains unverified" not in output
    ):
        raise AssertionError(output)
    if mode.startswith("mismatch") and "game checkpoint diverged" not in output:
        raise AssertionError(output)
    if mode in ("record-tail", "no-mode-tail") and "require replay mode" not in output:
        raise AssertionError(output)


def run_cases(executable: Path, directory: Path) -> None:
    cases = (
        ("record", 0),
        ("normal", 0),
        ("tail1", 1),
        ("tail3", 1),
        ("early", 1),
        ("mismatch-p", 1),
        ("mismatch-e", 1),
        ("record-tail", 0),
        ("no-mode-tail", 0),
        ("unknown", 2),
    )
    movie = directory / "sample.input"
    for mode, expected in cases:
        invalid = mode in ("record-tail", "no-mode-tail", "unknown")
        path = directory / f"{mode}.input" if invalid else movie
        before = movie.read_bytes() if movie.exists() else None
        result = subprocess.run(
            [str(executable), mode, str(path)],
            cwd=directory,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=10,
            check=False,
        )
        check_output(mode, result.stdout, result.returncode, expected)
        if invalid and path.exists():
            raise AssertionError(f"Rejected configuration created a file: {path}")
        if before is not None and movie.read_bytes() != before:
            raise AssertionError(f"{mode}: replay changed the original recording")
        print(f"PASS {mode}: process exit {expected}")
    print(f"All {len(cases)} input movie adapter cases passed.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    arguments = parser.parse_args()
    executable = arguments.executable.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="mgs-input-movie-test-") as directory:
        run_cases(executable, Path(directory))


if __name__ == "__main__":
    main()
