#!/usr/bin/env python3
"""Catch value returns from void Godot engine callbacks before project startup.

Some scripts are only loaded when a late-level scene opens, so a scene smoke
test alone does not establish that the entire GDScript tree is parseable.
The Godot headless importer remains the authoritative syntax check.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

VOID_CALLBACKS = frozenset({
    "_physics_process", "_process", "_ready", "_enter_tree", "_exit_tree",
    "_input", "_unhandled_input", "_unhandled_key_input", "_gui_input",
    "_notification", "_draw", "_integrate_forces", "_shortcut_input",
})
FUNCTION_RE = re.compile(r"^(?P<indent>[ \t]*)func[ \t]+(?P<name>[A-Za-z_][A-Za-z_0-9]*)\s*\(")
RETURN_RE = re.compile(r"^[ \t]*return(?P<rest>.*)$")


def check_source(filename: str, source: str) -> list[str]:
    errors: list[str] = []
    callback: str | None = None
    header_indent = 0
    for lineno, line in enumerate(source.splitlines(), 1):
        declaration = FUNCTION_RE.match(line)
        if declaration:
            name = declaration.group("name")
            callback = name if name in VOID_CALLBACKS else None
            header_indent = len(declaration.group("indent"))
            continue
        stripped = line.strip()
        if callback is None or not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" \t"))
        if indent <= header_indent:
            callback = None
            continue
        match = RETURN_RE.match(line)
        if match:
            rest = match.group("rest").strip()
            if rest and not rest.startswith("#"):
                errors.append(
                    f"{filename}:{lineno}: {callback} returns a value "
                    f"({stripped}). Use bare `return`."
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", nargs="?", default=".", help="Godot project root")
    args = parser.parse_args()
    root = pathlib.Path(args.project)
    checked = 0
    errors: list[str] = []
    for script in sorted(root.rglob("*.gd")):
        if any(folder.startswith(".git") for folder in script.relative_to(root).parts):
            continue
        checked += 1
        errors.extend(check_source(str(script), script.read_text(encoding="utf-8")))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print(
            f"FAILED: {len(errors)} void-callback return error(s) "
            f"in {checked} GDScript files.", file=sys.stderr
        )
        return 1
    print(f"OK: checked {checked} GDScript files for value returns in void callbacks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
