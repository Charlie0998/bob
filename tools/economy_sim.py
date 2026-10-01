#!/usr/bin/env python3
"""Economy simulator for Reef Keepers.

Reads src/shared/Balance.json (the same file the game loads), plays a greedy
simulated player through a fixed login schedule, and reports:

  * the state of the reef at the end of day 1, day 7 and day 30
  * the active play time between unlocks, flagged when a gap falls outside the
    2-30 minute target from the design doc

The harvest and slot-cost math mirrors src/shared/ReefMath.luau. Keep them in
sync when either changes.

Usage:
    python3 tools/economy_sim.py [--balance path] [--tick seconds]
"""

from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BALANCE = ROOT / "src" / "shared" / "Balance.json"

HOUR = 3600
DAY = 24 * HOUR

# (start offset within the day in hours, session length in minutes)
DAY_ONE_SESSIONS = [(0, 20), (4, 10), (10, 10)]
LATER_DAY_SESSIONS = [(0, 15), (6, 15), (12, 15)]

GAP_MIN_SECONDS = 2 * 60
GAP_MAX_SECONDS = 30 * 60
REPORT_DAYS = (1, 7, 30)


# --- Mirrors ReefMath.luau -------------------------------------------------

def ready_cycles(planted_at: float, now: float, grow: float, cap: float) -> tuple[int, bool]:
    """Return (cycles ready, whether the offline cap clipped them)."""
    elapsed = max(0.0, now - planted_at)
    raw = math.floor(elapsed / grow)
    max_cycles = max(1, math.floor(cap / grow))
    return min(raw, max_cycles), raw > max_cycles


def harvest(planted_at: float, now: float, grow: float, pearls: int, cap: float) -> tuple[int, float]:
    cycles, capped = ready_cycles(planted_at, now, grow, cap)
    if cycles == 0:
        return 0, planted_at
    new_planted = now if capped else planted_at + cycles * grow
    return cycles * pearls, new_planted


def slot_cost(slots_owned: int, balance: dict) -> int:
    n = slots_owned - balance["startingSlots"]
    return math.floor(balance["slotCostBase"] * balance["slotCostGrowth"] ** n + 0.5)


def health_score(corals: dict, slots: int, now: float, balance: dict) -> int:
    """Mirrors ReefHealth.score."""
    cfg = balance["reefHealth"]
    if not corals:
        return 0
    kinds = {k for k, _ in corals.values()}
    cared = sum(1 for _, planted in corals.values() if now - planted < balance["offlineCapSeconds"])
    w = cfg["weights"]
    variety = min(1, len(kinds) / cfg["varietyTarget"])
    density = min(1, len(corals) / max(1, slots))
    care = cared / len(corals)
    return math.floor(100 * (w["variety"] * variety + w["density"] * density + w["care"] * care) + 0.5)


def health_multiplier(score: int, balance: dict) -> float:
    """Mirrors ReefHealth.tier(...).multiplier."""
    best = balance["reefHealth"]["tiers"][0]
    for tier in balance["reefHealth"]["tiers"]:
        if score >= tier["min"]:
            best = tier
    return best["multiplier"]


def rotating_coral(now: float, balance: dict) -> str | None:
    """Approximates ShopRotation.current. The game seeds Roblox's Random by
    period, which Python can't reproduce exactly, but the stock rate matches."""
    cfg = balance["shopRotation"]
    rng = random.Random(int(now // cfg["periodSeconds"]))
    if not cfg["pool"] or rng.random() >= cfg["stockChance"]:
        return None
    return cfg["pool"][rng.randrange(len(cfg["pool"]))]


def required_slots(level: int, balance: dict) -> int:
    """Mirrors PrestigeService.requiredSlots: the bar rises with each reset."""
    cfg = balance["prestige"]
    return min(balance["maxSlots"], cfg["requiredSlots"] + level * cfg["requiredSlotsPerLevel"])


# --- Simulation -------------------------------------------------------------

@dataclass
class Player:
    balance: dict
    pearls: int = 0
    slots: int = 0
    corals: dict[int, tuple[str, float]] = field(default_factory=dict)
    active_seconds: float = 0.0
    unlocks: list[tuple[float, float, str]] = field(default_factory=list)  # (active, wall, label)
    seen_types: set[str] = field(default_factory=set)
    tide_level: int = 0
    resets: list[tuple[float, float]] = field(default_factory=list)  # (active, wall)

    def __post_init__(self) -> None:
        self.pearls = self.balance["startingPearls"]
        self.slots = self.balance["startingSlots"]
        starter = self.balance["starterCoral"]
        self.corals[1] = (starter, 0.0)
        self.seen_types.add(starter)

    def unlock(self, now: float, label: str) -> None:
        self.unlocks.append((self.active_seconds, now, label))

    def multiplier(self, now: float) -> float:
        b = self.balance
        health = health_multiplier(health_score(self.corals, self.slots, now, b), b)
        return health * (1 + self.tide_level * b["prestige"]["multiplierPerLevel"])

    def best_affordable_coral(self, now: float) -> str | None:
        best, best_rate = None, -1.0
        rotating = rotating_coral(now, self.balance)
        for name, c in self.balance["corals"].items():
            buyable = c["inShop"] or name == rotating
            if not buyable or self.slots < c["unlockSlots"] or c["cost"] > self.pearls:
                continue
            rate = c["pearls"] / c["growSeconds"]
            if rate > best_rate:
                best, best_rate = name, rate
        return best

    def act(self, now: float) -> None:
        b = self.balance
        cap = b["offlineCapSeconds"]
        for slot, (kind, planted) in list(self.corals.items()):
            c = b["corals"][kind]
            gained, new_planted = harvest(planted, now, c["growSeconds"], c["pearls"], cap)
            if gained:
                self.pearls += math.floor(gained * self.multiplier(now))
                self.corals[slot] = (kind, new_planted)

        if self.slots >= required_slots(self.tide_level, b):
            self.tide_level += 1
            self.resets.append((self.active_seconds, now))
            self.unlock(now, f"TIDE RESET {self.tide_level}")
            self.pearls = b["startingPearls"]
            self.slots = b["startingSlots"]
            self.corals = {1: (b["starterCoral"], now)}

        while True:
            empty = [s for s in range(1, self.slots + 1) if s not in self.corals]
            if empty:
                kind = self.best_affordable_coral(now)
                if kind is None:
                    return
                self.pearls -= b["corals"][kind]["cost"]
                self.corals[empty[0]] = (kind, now)
                if kind not in self.seen_types:
                    self.seen_types.add(kind)
                    self.unlock(now, f"first {kind}")
                continue
            if self.slots < b["maxSlots"] and self.pearls >= slot_cost(self.slots, b):
                self.pearls -= slot_cost(self.slots, b)
                self.slots += 1
                self.unlock(now, f"slot {self.slots}")
                continue
            return


def sessions(days: int):
    for day in range(days):
        plan = DAY_ONE_SESSIONS if day == 0 else LATER_DAY_SESSIONS
        for start_h, length_min in plan:
            yield day, day * DAY + start_h * HOUR, length_min * 60


def fmt_minutes(seconds: float) -> str:
    return f"{seconds / 60:6.1f} min"


def income_per_hour(p: Player) -> float:
    corals = p.balance["corals"]
    return sum(corals[k]["pearls"] / corals[k]["growSeconds"] * HOUR for k, _ in p.corals.values())


def run(balance: dict, tick: float) -> None:
    p = Player(balance)
    last_day = max(REPORT_DAYS)
    reported: set[int] = set()

    def report(day: int) -> None:
        counts: dict[str, int] = {}
        for kind, _ in p.corals.values():
            counts[kind] = counts.get(kind, 0) + 1
        coral_str = ", ".join(f"{k} x{v}" for k, v in sorted(counts.items()))
        print(f"\n== End of day {day} ==")
        print(f"  active play      {fmt_minutes(p.active_seconds)}")
        print(f"  pearls           {p.pearls}")
        print(f"  slots            {p.slots}/{balance['maxSlots']}  (next costs {slot_cost(p.slots, balance)})")
        print(f"  corals           {coral_str}")
        print(f"  active income    {income_per_hour(p):,.0f} pearls/hour")

    for day, start, length in sessions(last_day):
        for d in REPORT_DAYS:
            if d <= day and d not in reported:
                report(d)
                reported.add(d)
        t = start
        while t < start + length:
            p.act(t)
            t += tick
            p.active_seconds += tick
    for d in REPORT_DAYS:
        if d not in reported:
            report(d)

    # Purchases made in the same moment (e.g. spending a pile of offline pearls
    # on login) count as one unlock moment.
    moments: list[tuple[float, float, list[str]]] = []
    for active, wall, label in p.unlocks:
        if moments and moments[-1][1] == wall:
            moments[-1][2].append(label)
        else:
            moments.append((active, wall, [label]))

    print("\n== Unlock gaps (active play time since previous unlock moment) ==")
    prev_active = 0.0
    out_of_range = 0
    for active, wall, labels in moments:
        gap = active - prev_active
        prev_active = active
        label = labels[0] if len(labels) == 1 else f"{labels[0]} .. {labels[-1]} ({len(labels)} unlocks)"
        flag = ""
        if gap < GAP_MIN_SECONDS:
            flag = "  < 2 min"
        elif gap > GAP_MAX_SECONDS:
            flag = "  > 30 min"
        if flag:
            out_of_range += 1
        print(f"  day {int(wall // DAY) + 1:>2}  {fmt_minutes(gap)}  {label}{flag}")
    print(f"\n{len(p.unlocks)} unlocks in {len(moments)} moments, {out_of_range} outside the 2-30 minute target.")
    print("\n== Tide Resets (design target: first one after ~10 hours of play over 1-2 weeks) ==")
    if not p.resets:
        print("  none within the simulated days")
    for i, (active, wall) in enumerate(p.resets, start=1):
        print(f"  reset {i}: day {int(wall // DAY) + 1}, after {active / 3600:.1f} hours of play")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--balance", type=Path, default=DEFAULT_BALANCE)
    parser.add_argument("--tick", type=float, default=5.0, help="seconds between player actions while online")
    args = parser.parse_args()
    run(json.loads(args.balance.read_text()), args.tick)


if __name__ == "__main__":
    main()
