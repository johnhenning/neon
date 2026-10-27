"""Regenerate native icon resources from the two supplied originals (macOS/Xcode)."""
import json
import subprocess
from pathlib import Path

NATIVE = Path(__file__).resolve().parents[1]
RESOURCES = NATIVE / "resources"
ORIGINALS = RESOURCES / "app-icons"


def resize(source, destination, pixels):
    subprocess.run(
        ["sips", "-z", str(pixels), str(pixels), str(source), "--out", str(destination)],
        check=True,
        stdout=subprocess.DEVNULL,
    )


for appearance in ("light", "dark"):
    source = ORIGINALS / f"{appearance}.png"
    subprocess.run(
        ["swift", str(NATIVE / "scripts/render_app_icon.swift"), str(source),
         str(ORIGINALS / f"macos-{appearance}.png")],
        check=True,
    )
    resize(source, RESOURCES / "ios-icons.xcassets/AppIcon.appiconset" /
           f"{appearance}-1024@1x.png", 1024)

catalog = RESOURCES / "macos-icons.xcassets/AppIcon.appiconset"
for entry in json.loads((catalog / "Contents.json").read_text())["images"]:
    pixels = int(entry["size"].split("x")[0]) * int(entry["scale"][0])
    resize(ORIGINALS / "macos-light.png", catalog / entry["filename"], pixels)
