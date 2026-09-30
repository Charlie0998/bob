#!/usr/bin/env python3
"""Checks that ReefMath.luau and the Python mirror in tools/economy_sim.py agree.

Needs the `luau` CLI (https://github.com/luau-lang/luau/releases) on PATH, or
its path in the LUAU environment variable.

Usage:
    python3 tests/reefmath_parity.py
"""

from __future__ import annotations

import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import economy_sim as sim  # noqa: E402

DRIVER = """
local ReefMath = require("./ReefMath")
local balance = {balance}
local cases = {{
{cases}
}}
for _, c in cases do
	local gained, planted = ReefMath.harvest(c[1], c[2], c[3], c[4], c[5])
	print(string.format("%d %.3f %d", gained, planted, ReefMath.slotCost(c[6], balance)))
end
"""


def luau_table(d: dict) -> str:
    return "{" + ", ".join(f"{k} = {v}" for k, v in d.items()) + "}"


def main() -> int:
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        print("luau CLI not found; set LUAU or add it to PATH", file=sys.stderr)
        return 2

    balance = json.loads((ROOT / "src/shared/Balance.json").read_text())
    slot_balance = {k: balance[k] for k in ("startingSlots", "maxSlots", "slotCostBase", "slotCostGrowth", "offlineCapSeconds")}

    rng = random.Random(7)
    cases = []
    for _ in range(2000):
        coral = rng.choice(list(balance["corals"].values()))
        planted = rng.randint(0, 10_000_000)
        now = planted + rng.choice([rng.randint(-100, 300), rng.randint(0, 200_000)])
        slots = rng.randint(balance["startingSlots"], balance["maxSlots"])
        cases.append((planted, now, coral["growSeconds"], coral["pearls"], balance["offlineCapSeconds"], slots))

    with tempfile.TemporaryDirectory() as tmp:
        # The luau CLI has no io library and resolves require relative to the
        # script, so copy the module next to a driver with the cases inlined.
        shutil.copy(ROOT / "src/shared/ReefMath.luau", Path(tmp) / "ReefMath.luau")
        driver = Path(tmp) / "driver.luau"
        rows = ",\n".join("{" + ", ".join(map(str, c)) + "}" for c in cases)
        driver.write_text(DRIVER.format(balance=luau_table(slot_balance), cases=rows))
        out = subprocess.run([luau, str(driver)], capture_output=True, text=True, check=True).stdout.split("\n")

    failures = 0
    for case, line in zip(cases, out):
        planted, now, grow, pearls, cap, slots = case
        gained, new_planted = sim.harvest(planted, now, grow, pearls, cap)
        expected = f"{gained} {new_planted:.3f} {sim.slot_cost(slots, balance)}"
        if line != expected:
            failures += 1
            if failures <= 5:
                print(f"mismatch for {case}: luau={line!r} python={expected!r}")
    print(f"{len(cases)} cases, {failures} mismatches")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
