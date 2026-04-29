#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def update_or_insert_line(content: str, pattern: str, replacement: str, insert_after_pattern: str) -> str:
    if re.search(pattern, content):
        return re.sub(pattern, replacement, content)

    return re.sub(insert_after_pattern, lambda match: match.group(0) + "\n" + replacement, content, count=1)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python tools/set_version.py <version> <code>")
        print("Example: python tools/set_version.py 1.0.1 2")
        return 1

    version = sys.argv[1]
    try:
        code = int(sys.argv[2])
    except ValueError:
        print("Error: code must be an integer")
        return 1

    root = Path(__file__).resolve().parents[1]
    project_path = root / "project.godot"
    export_path = root / "export_presets.cfg"

    project = project_path.read_text(encoding="utf-8")
    project = update_or_insert_line(
        project,
        r'config/version="[^"]*"',
        f'config/version="{version}"',
        r'config/name="[^"]*"',
    )
    project = update_or_insert_line(
        project,
        r"config/version_code=\d+",
        f"config/version_code={code}",
        r'config/version="[^"]*"',
    )
    project_path.write_text(project, encoding="utf-8")

    export = export_path.read_text(encoding="utf-8")
    export = re.sub(r"version/code=\d+", f"version/code={code}", export)
    export = re.sub(r'version/name="[^"]*"', f'version/name="{version}"', export)
    export_path.write_text(export, encoding="utf-8")

    print(f"Version updated: {version} ({code})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
