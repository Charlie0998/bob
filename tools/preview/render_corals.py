#!/usr/bin/env python3
"""Renders the procedural corals from src/shared/CoralModels.luau to a PNG.

Runs the real CoralModels.luau in the standalone `luau` CLI against the small
Roblox datatype mock in robloxmock.luau, then draws every part with
matplotlib. Handy for checking shapes without opening Studio.

Needs the `luau` CLI on PATH (or LUAU=/path/to/luau) and matplotlib.

Usage:
    python3 tools/preview/render_corals.py [-o docs/coral_preview.png]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from mpl_toolkits.mplot3d.art3d import Poly3DCollection  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

DUMP = """
local function dump(model, label)
	for _, part in model:GetChildren() do
		if part.ClassName == "Part" and part.Transparency < 1 then
			local sphere = false
			for _, child in part:GetChildren() do
				if child.ClassName == "SpecialMesh" then sphere = true end
			end
			local c = part.CFrame
			print(table.concat({
				label, part.Shape, tostring(sphere),
				part.Size.X, part.Size.Y, part.Size.Z,
				c.p.X, c.p.Y, c.p.Z,
				table.concat(c.r, ","),
				part.Color.R, part.Color.G, part.Color.B,
				part.Transparency, part.Material,
			}, "|"))
		end
	end
end
local balance = {balance}
for _, name in {names} do
	dump(CoralModels.build(name, balance[name].color, 7), name)
end
"""


def build_driver() -> str:
    mock = (HERE / "robloxmock.luau").read_text()
    models = (ROOT / "src/shared/CoralModels.luau").read_text()
    balance = json.loads((ROOT / "src/shared/Balance.json").read_text())
    names = list(balance["corals"])
    lua_balance = "{" + ", ".join(f'{n} = {{ color = {{{", ".join(map(str, c["color"]))}}} }}' for n, c in balance["corals"].items()) + "}"
    lua_names = "{" + ", ".join(f'"{n}"' for n in names) + "}"
    globals_ = "Vector3, CFrame, Color3, Random, Enum, Instance, NumberSequence, ColorSequence, NumberRange, Vector2, NumberSequenceKeypoint"
    unpack = ", ".join(f"M.{g.strip()}" for g in globals_.split(","))
    return (
        f"local M = (function()\n{mock}\nend)()\n"
        f"local {globals_} = {unpack}\n"
        f"local CoralModels = (function()\n{models}\nend)()\n"
        + DUMP.replace("{balance}", lua_balance).replace("{names}", lua_names)
    )


def unit_mesh(kind: str, n: int = 14):
    """Unit shape surfaces in local space: a list of (x, y, z) grids."""
    u, v = np.meshgrid(np.linspace(0, 2 * np.pi, n), np.linspace(0, np.pi, n))
    if kind == "sphere":
        return [(np.cos(u) * np.sin(v), np.cos(v), np.sin(u) * np.sin(v))]
    if kind == "cylinder":  # axis along X, from -1 to 1
        t, a = np.meshgrid(np.linspace(-1, 1, 2), np.linspace(0, 2 * np.pi, n))
        side = (t, np.cos(a), np.sin(a))
        r, a2 = np.meshgrid(np.linspace(0, 1, 2), np.linspace(0, 2 * np.pi, n))
        caps = [(np.full_like(r, s), r * np.cos(a2), r * np.sin(a2)) for s in (-1, 1)]
        return [side, *caps]
    # box: six faces
    g = np.linspace(-1, 1, 2)
    a, b = np.meshgrid(g, g)
    one = np.ones_like(a)
    return [
        (one * s, a, b) for s in (-1, 1)
    ] + [(a, one * s, b) for s in (-1, 1)] + [(a, b, one * s) for s in (-1, 1)]


LIGHT = np.array([0.4, 0.8, 0.45]) / np.linalg.norm([0.4, 0.8, 0.45])


def part_polygons(part):
    """Shaded quads for one part, in matplotlib's Z-up coordinates."""
    shape, sphere = part["shape"], part["sphere"]
    if sphere or shape.endswith("Ball"):
        kind = "sphere"
    elif shape.endswith("Cylinder"):
        kind = "cylinder"
    else:
        kind = "box"
    half = np.array(part["size"]) / 2
    if kind == "cylinder":
        half = np.array([half[0], half[1], half[1]])
    elif shape.endswith("Ball"):
        half = np.array([half[0]] * 3)
    r = np.array(part["r"]).reshape(3, 3)
    p = np.array(part["pos"])
    base = np.clip(np.array(part["color"]), 0, 1)
    neon = part["material"].endswith("Neon")
    alpha = max(0.2, 1 - part["transparency"])
    polys, colors = [], []
    for x, y, z in unit_mesh(kind):
        pts = np.stack([x * half[0], y * half[1], z * half[2]], axis=-1) @ r.T + p
        pts = pts[..., [0, 2, 1]] * np.array([1, -1, 1])  # Roblox Y-up -> matplotlib Z-up
        for i in range(pts.shape[0] - 1):
            for j in range(pts.shape[1] - 1):
                quad = np.array([pts[i, j], pts[i + 1, j], pts[i + 1, j + 1], pts[i, j + 1]])
                normal = np.cross(quad[2] - quad[0], quad[3] - quad[1])
                norm = np.linalg.norm(normal)
                if norm < 1e-9:
                    continue
                light = 1.0 if neon else 0.45 + 0.55 * abs(normal @ LIGHT) / norm
                polys.append(quad)
                colors.append((*np.clip(base * light * (1.2 if neon else 1.0), 0, 1), alpha))
    return polys, colors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-o", "--out", type=Path, default=ROOT / "docs" / "coral_preview.png")
    args = parser.parse_args()

    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        print("luau CLI not found; set LUAU or add it to PATH", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory() as tmp:
        driver = Path(tmp) / "driver.luau"
        driver.write_text(build_driver())
        result = subprocess.run([luau, str(driver)], capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout, result.stderr, file=sys.stderr)
        return 1

    models: dict[str, list[dict]] = {}
    for line in result.stdout.strip().splitlines():
        f = line.split("|")
        models.setdefault(f[0], []).append({
            "shape": f[1],
            "sphere": f[2] == "true",
            "size": list(map(float, f[3:6])),
            "pos": list(map(float, f[6:9])),
            "r": list(map(float, f[9].split(","))),
            "color": list(map(float, f[10:13])),
            "transparency": float(f[13]),
            "material": f[14],
        })

    fig = plt.figure(figsize=(4 * len(models), 4.6), facecolor=(0.08, 0.25, 0.32))
    for i, (name, parts) in enumerate(models.items(), start=1):
        ax = fig.add_subplot(1, len(models), i, projection="3d")
        ax.set_facecolor((0.08, 0.25, 0.32))
        polys, colors = [], []
        for part in parts:
            part_polys, part_colors = part_polygons(part)
            polys += part_polys
            colors += part_colors
        # One collection, so matplotlib depth-sorts every face together.
        ax.add_collection3d(Poly3DCollection(polys, facecolors=colors, edgecolors="none"))
        ax.set_xlim(-2.5, 2.5)
        ax.set_ylim(-2.5, 2.5)
        ax.set_zlim(0, 5)
        ax.set_box_aspect((1, 1, 1))
        ax.view_init(elev=18, azim=-60)
        ax.set_axis_off()
        ax.set_title(f"{name}  ({len(parts)} parts)", color="white", fontsize=13)
    fig.tight_layout()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.out, dpi=90, facecolor=fig.get_facecolor())
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
