"""Check world-audit logging, opt-in strict failure and invalid configuration."""

import subprocess
import sys


def main() -> None:
    executable = sys.argv[1]
    for mode, expected_code in (
        ("log", 0),
        ("detail", 0),
        ("strict", 1),
        ("invalid", 1),
    ):
        result = subprocess.run(
            [executable, mode], capture_output=True, text=True, check=False, timeout=10
        )
        if result.returncode != expected_code:
            raise AssertionError(
                f"{mode}: exit {result.returncode}\n{result.stdout}\n{result.stderr}"
            )
        lines = [
            line
            for line in result.stdout.splitlines()
            if line.startswith("MGS_WORLD_COVERAGE ")
        ]
        expected_lines = {"log": 2, "detail": 2, "strict": 1, "invalid": 0}[mode]
        if len(lines) != expected_lines:
            raise AssertionError(
                f"{mode}: expected {expected_lines} coverage records, got {lines}"
            )
        if mode == "log" and not ("epoch=1" in lines[0] and "epoch=2" in lines[1]):
            raise AssertionError(f"Stage generations were not distinguished: {lines}")
        if (
            mode == "strict"
            and "unsupported native world content in s12c" not in result.stderr
        ):
            raise AssertionError(
                f"Strict mode failed without a diagnostic: {result.stderr}"
            )
        details = [
            line
            for line in result.stdout.splitlines()
            if line.startswith("MGS_WORLD_UNSUPPORTED ")
        ]
        if mode == "detail":
            if (
                len(details) != 4
                or "model=00001234 part=1 faces=1" not in details[0]
                or "texture=00005678" not in details[1]
            ):
                raise AssertionError(f"Missing model/effect attribution: {details}")
        elif details:
            raise AssertionError(f"Unexpected detailed audit for {mode}: {details}")
        if (
            mode == "invalid"
            and "MGS_GODOT_WORLD_AUDIT=log or strict" not in result.stderr
        ):
            raise AssertionError(
                f"Invalid mode failed without a diagnostic: {result.stderr}"
            )
    result = subprocess.run(
        [executable, "strict", "supported"],
        capture_output=True,
        text=True,
        check=True,
        timeout=10,
    )
    if (
        "meshes_compat=0" not in result.stdout
        or "effects_compat=0" not in result.stdout
    ):
        raise AssertionError(
            f"Strict supported-content check was not clean: {result.stdout}"
        )
    print("World audit logging and strict/invalid failure diagnostics pass")


if __name__ == "__main__":
    main()
