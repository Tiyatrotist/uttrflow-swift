#!/usr/bin/env python3
"""Fails when a shared-token text role falls below WCAG AA contrast on its artboard surface.

Two checks, both against `Design/`:

1. The menu bar artboard draws a translucent native-style menu (`rgba(250,250,253,0.72)`)
   over a radial gradient with three declared stops. The two text rows in the attention
   state — the status row and the recovery action — must clear 4.5:1 against every
   composited background the gradient can produce, because the backdrop blur cannot lift
   the menu above the gradient's brightest source stop.
2. The shared `--red-ink` token (`.btn.destructive` and any row that highlights an
   over-threshold count) must clear 4.5:1 against the opaque window background it is drawn
   on, light and dark, so it stays the readable critical ink rather than the bright
   `--red` fill.

Every artboard shares `Design/_gen_common.py` and `Design/_gen_shell.py`, so both checks
run against those generators rather than any one `.dc.html` file. The regeneration contract
— a second generator run leaves the worktree clean — is `Scripts/docs_audit.sh`'s to
enforce, not this script's.
"""

import argparse
import os
import re
import sys


GRADIENT = re.compile(
    r"radial-gradient\(\s*[^,]+,\s*(?P<a>#[0-9A-Fa-f]{6})\s+0%,\s*"
    r"(?P<b>#[0-9A-Fa-f]{6})\s+45%,\s*(?P<c>#[0-9A-Fa-f]{6})\s+100%\s*\)"
)
MENU_FILL = re.compile(
    r"\.menu\s*\{[^}]*background:\s*rgba?\(\s*"
    r"(?P<r>\d+)\s*,\s*(?P<g>\d+)\s*,\s*(?P<b>\d+)\s*(?:,\s*(?P<a>[\d.]+)\s*)?\)",
    re.DOTALL,
)
ATTENTION_STYLE = re.compile(
    r"ATTENTION_MENU\s*=\s*menu\(f?\"\"\"(?P<body>.*?)\"\"\"\s*\)", re.DOTALL
)
INLINE_COLOR = re.compile(r'style="color:\s*(?P<color>#[0-9A-Fa-f]{6}|var\(--[\w-]+\))"')


REQUIRED_RATIO = 4.5
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "Design", "_gen_menubar.py"))
COMMON_SOURCE = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "Design", "_gen_common.py"))
SHELL_SOURCE = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "Design", "_gen_shell.py"))

TOKEN_HEX_LINE = r"--{name}:\s*(?P<hex>#[0-9A-Fa-f]{{6}});"


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def linearize(channel):
    return channel / 12.92 if channel <= 0.03928 else ((channel + 0.055) / 1.055) ** 2.4


def relative_luminance(rgb):
    r, g, b = (linearize(channel) for channel in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(fg, bg):
    light = relative_luminance(fg)
    dark = relative_luminance(bg)
    lighter, darker = max(light, dark), min(light, dark)
    return (lighter + 0.05) / (darker + 0.05)


def composite(fg_rgba, bg_opaque):
    """Composite a translucent fill over an opaque background (Porter-Duff over)."""
    fr, fg_, fb, fa = fg_rgba
    br, bg_, bb = bg_opaque
    return (
        br * (1 - fa) + fr * fa,
        bg_ * (1 - fa) + fg_ * fa,
        bb * (1 - fa) + fb * fa,
    )


def load_colors(path):
    """Pull the gradient stops, the menu fill, and the two attention-row text colors.

    Returns (stops, fill, [(label, fg_hex)]) where each `fg_hex` is a 6-digit string and the
    `label` is the menu-row text that identifies the foreground.
    """
    text = open(path).read()

    gradient = GRADIENT.search(text)
    if not gradient:
        raise SystemExit(f"design contrast audit: no radial-gradient found in {path}")
    stops = [hex_to_rgb(gradient.group(k)) for k in ("a", "b", "c")]

    fill = MENU_FILL.search(text)
    if not fill:
        raise SystemExit(f"design contrast audit: no .menu background fill found in {path}")
    r = int(fill.group("r")) / 255.0
    g = int(fill.group("g")) / 255.0
    b = int(fill.group("b")) / 255.0
    a = float(fill.group("a") or "1")
    menu_fill = (r, g, b, a)

    attention = ATTENTION_STYLE.search(text)
    if not attention:
        raise SystemExit(f"design contrast audit: ATTENTION_MENU not found in {path}")

    rows = []
    for match in INLINE_COLOR.finditer(attention.group("body")):
        color = match.group("color")
        rows.append((match.string[match.start():match.end()], color))

    if len(rows) != 2:
        raise SystemExit(
            f"design contrast audit: expected two attention-row text colors in {path}, found {len(rows)}"
        )

    return stops, menu_fill, rows


# Resolve a foreground token. The accent is the only `var(--…)` token the menu uses as text;
# if a future generator routes the recovery row through a deeper accent, the check stays
# pinned to whatever the file says.
TOKEN_HEX = {
    "--accent": "#128077",
}


def resolve(color):
    if color.startswith("var("):
        name = color[4:].rstrip(")")
        if name not in TOKEN_HEX:
            raise SystemExit(
                f"design contrast audit: unknown token {color!r}; add it to TOKEN_HEX"
            )
        return hex_to_rgb(TOKEN_HEX[name])
    return hex_to_rgb(color)


# A foreground / composited-background pair that fails or passes 4.5:1; the self-test exercises
# both the pass and the fail arms so the audit cannot regress to a no-op.
SELF_TEST_PAIRS = (
    ("#793F15", (0.827, 0.863, 0.886), 5.97, "pass"),
    ("#C2560C", (0.827, 0.863, 0.886), 3.27, "fail"),
)


def self_test():
    wrong = []
    for fg_hex, bg_rgb, expected, outcome in SELF_TEST_PAIRS:
        ratio = contrast_ratio(hex_to_rgb(fg_hex), bg_rgb)
        passes = ratio >= REQUIRED_RATIO
        if outcome == "pass" and not passes:
            wrong.append((fg_hex, ratio, outcome))
        if outcome == "fail" and passes:
            wrong.append((fg_hex, ratio, outcome))
    for fg_hex, ratio, outcome in wrong:
        print(
            f"  ✗ self-test: {fg_hex} ratio {ratio:.3f}:1 expected to {outcome}",
            file=sys.stderr,
        )
    return not wrong


def load_token(path, name):
    text = open(path).read()
    match = re.search(TOKEN_HEX_LINE.format(name=re.escape(name)), text)
    if not match:
        raise SystemExit(f"design contrast audit: no --{name} declaration found in {path}")
    return match.group("hex")


# The shared destructive/critical-count text role, checked against the opaque window
# background it sits on in each appearance — light from `_gen_common.py`'s root tokens,
# dark from `_gen_shell.py`'s `.theme-dark` override of the same token names.
DESTRUCTIVE_SURFACES = (
    ("light", COMMON_SOURCE, COMMON_SOURCE),
    ("dark", SHELL_SOURCE, SHELL_SOURCE),
)


def audit_destructive_text():
    failures = []
    rows = []
    for theme, ink_source, bg_source in DESTRUCTIVE_SURFACES:
        ink_hex = load_token(ink_source, "red-ink")
        bg_hex = load_token(bg_source, "window-bg")
        ratio = contrast_ratio(hex_to_rgb(ink_hex), hex_to_rgb(bg_hex))
        verdict = "pass" if ratio >= REQUIRED_RATIO else "FAIL"
        rows.append((theme, ink_hex, bg_hex, ratio, verdict))
        if ratio < REQUIRED_RATIO:
            failures.append((theme, ink_hex, bg_hex, ratio))
    return rows, failures


def audit():
    if not os.path.isfile(SOURCE):
        print(f"design contrast audit: {SOURCE} not found", file=sys.stderr)
        return 1

    stops, fill, rows = load_colors(SOURCE)
    composited = [composite(fill, stop) for stop in stops]

    print("Menu-bar attention state, text contrast against composited backgrounds")
    print(f"  gradient stops: {len(stops)}")
    print(f"  menu fill alpha: {fill[3]:.2f}")
    failures = []
    for fg_label, fg_color in rows:
        fg = resolve(fg_color)
        ratios = [contrast_ratio(fg, bg) for bg in composited]
        worst = min(ratios)
        verdict = "pass" if worst >= REQUIRED_RATIO else "FAIL"
        print(f"  {fg_label}  {fg_color}  worst {worst:.2f}:1  [{verdict}]")
        if worst < REQUIRED_RATIO:
            failures.append((fg_label, fg_color, worst))

    if failures:
        print(
            f"\n  ✗ {len(failures)} attention row(s) fall below WCAG AA text contrast "
            f"({REQUIRED_RATIO:.2f}:1) over the menu's composited backgrounds:",
            file=sys.stderr,
        )
        for fg_label, fg_color, worst in failures:
            print(
                f"    {fg_label}  {fg_color}  worst {worst:.2f}:1",
                file=sys.stderr,
            )
        print(
            "    The menu is translucent over a gradient; backdrop blur cannot lift the backing\n"
            "    above the gradient's brightest stop, so every stop is a real worst case.\n"
            "    Pick a deeper foreground and re-run; see `Design/_gen_menubar.py`.",
            file=sys.stderr,
        )
        return 1

    print(f"\ndesign contrast audit: every attention text row clears {REQUIRED_RATIO:.2f}:1.\n")

    print("Destructive/critical-count text, contrast against the window background")
    destructive_rows, destructive_failures = audit_destructive_text()
    for theme, ink_hex, bg_hex, ratio, verdict in destructive_rows:
        print(f"  {theme}  {ink_hex} on {bg_hex}  {ratio:.2f}:1  [{verdict}]")

    if destructive_failures:
        print(
            f"\n  ✗ {len(destructive_failures)} destructive/critical-count text role(s) fall "
            f"below WCAG AA text contrast ({REQUIRED_RATIO:.2f}:1):",
            file=sys.stderr,
        )
        for theme, ink_hex, bg_hex, ratio in destructive_failures:
            print(f"    {theme}  {ink_hex} on {bg_hex}  {ratio:.2f}:1", file=sys.stderr)
        print(
            "    `--red-ink` is the readable text role; `--red` is the bright fill and never\n"
            "    carries text. See `Design/_gen_common.py` and `Design/_gen_shell.py`.",
            file=sys.stderr,
        )
        return 1

    print(f"\ndesign contrast audit: destructive/critical-count text clears {REQUIRED_RATIO:.2f}:1.\n")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="prove the audit catches both a passing and a failing contrast pair",
    )
    options = parser.parse_args()

    if options.self_test:
        if not self_test():
            print(
                "\ndesign contrast audit: self-test failed; the ratio predicate is broken.\n",
                file=sys.stderr,
            )
            return 1
        return 0

    return audit()


if __name__ == "__main__":
    sys.exit(main())
