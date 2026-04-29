#!/usr/bin/env python3
import re
from pathlib import Path


def find_value(pattern: str, content: str, default: str = "") -> str:
    match = re.search(pattern, content)
    if match:
        return match.group(1)
    return default


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    project = (root / "project.godot").read_text(encoding="utf-8")
    export = (root / "export_presets.cfg").read_text(encoding="utf-8")

    app_version = find_value(r'config/version="([^"]*)"', project, "unknown")
    app_version_code = find_value(r"config/version_code=(\d+)", project, "unknown")
    android_version_name = find_value(r'version/name="([^"]*)"', export, "unknown")
    android_version_code = find_value(r"version/code=(\d+)", export, "unknown")

    print(f"app_version={app_version}")
    print(f"app_version_code={app_version_code}")
    print(f"android_version_name={android_version_name}")
    print(f"android_version_code={android_version_code}")

    if app_version != android_version_name or app_version_code != android_version_code:
        print("warning=project.godot and export_presets.cfg versions differ")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
