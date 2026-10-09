#!/usr/bin/env python3
"""Check/apply the heading and term-universe fixes to pinned Verso.

No network or cache deletion. An exact source hash permits both Git dependencies
and stripped standalone scaffolds; unknown revisions/edits fail without writes.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess

BASE_REVISION = "3bdedf29bada13d8103e6c979001c51dcee210c8"  # v4.33.0
TARGET = Path("src/verso-manual/VersoManual.lean")
BEFORE = "021b6d9515d217ac1bcfe65035376ab75abc4efeea454b30ceff7bac627c8269"
AFTER = "f095c97f243a379aac6440289f4ec2b92d0683aa1726f3aa7257241e63e7cee8"
PATCH = Path(__file__).resolve().parents[1] / "patches/verso-chapter-anchors.patch"
PATCHES = (
    (TARGET, BEFORE, AFTER, PATCH),
    (Path("src/verso-manual/VersoManual/InlineLean.lean"),
     "3fb522e80fe6043345f3188b262f77838ad3b1c201064c4bb131a520387efc07",
     "1138712e7c82551bb84b3b86d43320fe22df569de416b71e86d3d17732ee933e",
     PATCH.with_name("verso-term-universes.patch")),
)


def apply(verso: Path, *, check: bool = False) -> str:
    verso = verso.resolve()
    pending = []
    # Validate EVERY target before applying ANY patch. In particular, an unknown
    # edit in the second file must leave the first file untouched.
    for relative, before, after, patch in PATCHES:
        target = verso / relative
        if target.is_symlink() or not target.is_file():
            raise ValueError(f"Missing regular Verso source: {target}; fetch dependencies first")
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if digest == after:
            continue
        if digest != before:
            raise ValueError(f"Unknown Verso source {target}: {digest}; review patch against pinned {BASE_REVISION}")
        pending.append((target, after, patch))
    if not pending:
        return "already patched"
    patches = [str(patch) for _, _, patch in pending]
    subprocess.run(["git", "apply", "--check", *patches], cwd=verso, check=True)
    if check:
        return "patchable"
    subprocess.run(["git", "apply", *patches], cwd=verso, check=True)
    for target, after, _ in pending:
        if hashlib.sha256(target.read_bytes()).hexdigest() != after:
            raise ValueError("Patched source checksum differs; stop before building")
    return "patched"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("verso", type=Path, help="Verso dependency directory")
    parser.add_argument("--check", action="store_true", help="Validate without changing source")
    args = parser.parse_args()
    try:
        print(apply(args.verso, check=args.check))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Verso patch: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
