#!/usr/bin/env python3
"""Checks WCAG text contrast for the UI palette.

Reads UIKit.COLORS and UIKit.GLOSS_SHADE straight from
src/client/UIKit.luau and checks every text/background pair the UI uses
against WCAG AA for normal text (4.5:1). Glossy elements are checked at
both the top (unshaded) and the bottom (shaded by GLOSS_SHADE), because
the shine's UIGradient multiplies the text and the background alike.

Text drawn straight over the 3D world (timers, "Next:" line, health line)
has no fixed background; those use a solid dark outline instead, which this
script also checks against the text color.

Usage:
    python3 tests/contrast_check.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UIKIT = ROOT / "src" / "client" / "UIKit.luau"
MINIMUM = 4.5

# (text color, background color, glossy?, where it's used)
PAIRS = [
    ("text", "panel", True, "panels, pearl counter, toasts, picker"),
    ("pearl", "panel", True, "pearl counter, pearl toasts"),
    ("ready", "panel", True, "unlock toasts"),
    ("hint", "panel", True, "panel hints"),
    ("text", "card", False, "card labels, book cards"),
    ("hint", "card", False, "card descriptions, book hints"),
    ("text", "card", True, "book tabs"),
    ("text", "muted", True, "locked buttons, muted buttons"),
    ("text", "muted", False, "undiscovered book cards, streak days"),
    ("hint", "muted", False, "undiscovered book hints"),
    ("text", "accent", True, "selected coral, selected tab, primary buttons"),
    ("text", "accent", False, "Make pet button, past streak days"),
    ("goldText", "gold", True, "gold buttons, event banner"),
    ("goldText", "gold", False, "today's streak day, current pet"),
    ("text", "coral", True, "close buttons"),
    ("text", "pink", True, "close buttons"),
    ("text", "purple", True, "shells counter, rare coral button"),
    ("text", "blue", True, "level badge"),
    ("text", "green", True, "green buttons"),
    ("text", "orange", True, "orange buttons"),
    ("text", "panel", False, "outline on text over the 3D world"),
    ("ready", "panel", False, "outline on 'Ready!' timers"),
]


def load() -> tuple[dict[str, tuple[int, int, int]], float]:
    source = UIKIT.read_text()
    block = source[source.index("UIKit.COLORS = {"):]
    block = block[: block.index("\n}")]
    colors = {
        name: (int(r), int(g), int(b))
        for name, r, g, b in re.findall(r"(\w+)\s*=\s*Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)", block)
    }
    shade = float(re.search(r"UIKit\.GLOSS_SHADE\s*=\s*([\d.]+)", source).group(1))
    return colors, shade


def luminance(rgb: tuple[float, float, float]) -> float:
    def channel(c: float) -> float:
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def main() -> int:
    colors, shade = load()
    failures = 0
    for fg, bg, glossy, where in PAIRS:
        ratios = [contrast(colors[fg], colors[bg])]
        if glossy:
            scaled = lambda c: tuple(v * shade for v in c)  # noqa: E731
            ratios.append(contrast(scaled(colors[fg]), scaled(colors[bg])))
        worst = min(ratios)
        ok = worst >= MINIMUM
        failures += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {worst:5.2f}:1  {fg:>8} on {bg:<7}{' (glossy)' if glossy else '          '}  {where}")
    print(f"\n{len(PAIRS)} pairs, {failures} below {MINIMUM}:1")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
