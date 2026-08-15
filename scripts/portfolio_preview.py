#!/usr/bin/env python3
"""Draw the Portfolio shell on a Linux host, where the app cannot be built.

Every size comes from Sources/Arkboard/UI/Theme/Typography.swift and every colour from
Hue.swift, so the picture answers the questions this pass is about: how much air the
sidebar rows get, whether the sidebar and the document read as different surfaces, and
whether the project mark is the hero of a card.

    python3 scripts/portfolio_preview.py [output-dir]

It is a geometry preview, not a screenshot. Real materials, vibrancy, SF Symbols and text
metrics are the system's; verify the finished screen on a Mac with ./scripts/run.sh.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Metrics from Sources/Arkboard/UI/Theme/Typography.swift
PANE_X = 24.0
CARD_PAD = 14.0
CARD_GAP = 12.0
SIDEBAR_IDEAL = 232.0
SIDEBAR_ROW_Y = 5.0
RADIUS_CARD = 10.0
CARD_POSTER_ASPECT = 1.5
MARK_SIDEBAR = 22.0
MARK_CORNER_RATIO = 0.2237
MARK_GLYPH_RATIO = 0.52
BODY = 13.0
HEADING = BODY + 3
CALLOUT = BODY - 1
CAPTION = max(10.0, BODY - 2)
MONO = BODY - 1
CARD_MIN, CARD_MAX = 320.0, 480.0

# Hue light values from Sources/Arkboard/UI/Theme/Hue.swift
VIOLET = "#8A54D6"
ROSE = "#D4436B"
AZURE = "#2C6FCF"
MAGENTA = "#B23FA8"
GOLD = "#A87908"
INDIGO = "#5A62D6"
MOSS = "#1F8F63"

PRIMARY = "#000000"
SECONDARY = "#6A6A6E"
TERTIARY = "#A0A0A6"
CARD_FILL = "#FFFFFF"
# NSColor.windowBackgroundColor, light. StudioColor.documentField.
DOCUMENT_FIELD = "#F5F5F5"
# The sidebar is system material, so it sits a shade off the document on purpose.
SIDEBAR_MATERIAL = "#FAFAFA"
TITLEBAR = "#F2F2F3"
HAIRLINE = "#D8D8DC"
# NSColor.unemphasizedSelectedContentBackgroundColor: the quiet selection.
SELECTION = "#DCDCE0"
FACE = "SF Pro Text, DejaVu Sans, Helvetica, Arial, sans-serif"
MONO_FACE = "SF Mono, DejaVu Sans Mono, Menlo, monospace"


def blend(base: str, over: str, alpha: float) -> str:
    """Composite `over` at `alpha` on opaque `base`, the way a wash sits on the field."""
    b = [int(base[i : i + 2], 16) for i in (1, 3, 5)]
    o = [int(over[i : i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(b[i] + (o[i] - b[i]) * alpha):02X}" for i in range(3))


# StudioColor.wash(hue, .light) is the hue at 6%.
PANE = blend(DOCUMENT_FIELD, VIOLET, 0.06)
CARD_STROKE = blend(CARD_FILL, VIOLET, 0.14)


def esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, s, size, fill=PRIMARY, weight="normal", face=FACE, anchor="start", opacity=1.0):
    return (
        f'<text x="{x:.1f}" y="{y:.1f}" font-family="{face}" font-size="{size:.1f}" '
        f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" '
        f'opacity="{opacity:g}">{esc(s)}</text>'
    )


def rect(x, y, w, h, fill, r=0.0, stroke=None, sw=1.0, opacity=1.0):
    out = (
        f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r:.1f}" '
        f'fill="{fill}" opacity="{opacity:g}"'
    )
    if stroke:
        out += f' stroke="{stroke}" stroke-width="{sw:g}"'
    return out + "/>"


def glyph(cx, cy, size, fill, opacity=1.0):
    """Stand-in for an SF Symbol: a mark of the right optical size, not the real symbol."""
    half = size / 2
    return (
        f'<g opacity="{opacity:g}" fill="{fill}">'
        + rect(cx - half, cy - half, size, size * 0.30, fill, r=size * 0.10)
        + rect(cx - half, cy - half + size * 0.36, size, size * 0.30, fill, r=size * 0.10)
        + rect(cx - half, cy - half + size * 0.72, size, size * 0.28, fill, r=size * 0.10)
        + "</g>"
    )


def mark_tile(x, y, size, color):
    corner = round(size * MARK_CORNER_RATIO)
    return (
        rect(x, y, size, size, blend(CARD_FILL, color, 0.16), r=corner)
        + glyph(x + size / 2, y + size / 2, round(size * MARK_GLYPH_RATIO), color)
    )


def sidebar(height: float, selected: int = 0) -> list[str]:
    """`selected`: 0 Portfolio, 1 Timeline, 2 the pinned project."""
    out = [rect(0, 0, SIDEBAR_IDEAL, height, SIDEBAR_MATERIAL)]
    row_h = BODY + 8 + SIDEBAR_ROW_Y * 2
    y = 12.0
    for index, label in enumerate(("Portfolio", "Timeline")):
        selected_row = index == selected
        if selected_row:
            out.append(rect(8, y, SIDEBAR_IDEAL - 16, row_h, SELECTION, r=6))
        hue = VIOLET if index == 0 else MOSS
        out.append(glyph(14 + MARK_SIDEBAR / 2, y + row_h / 2, 12, hue, 0.95))
        out.append(text(14 + MARK_SIDEBAR + 10, y + row_h / 2 + BODY * 0.36, label, BODY, PRIMARY))
        y += row_h
    y += SIDEBAR_ROW_Y
    out.append(f'<line x1="16" y1="{y:.1f}" x2="{SIDEBAR_IDEAL - 16:.1f}" y2="{y:.1f}" stroke="{HAIRLINE}" stroke-width="1"/>')
    y += SIDEBAR_ROW_Y + 4
    project_h = MARK_SIDEBAR + SIDEBAR_ROW_Y * 2
    if selected == 2:
        out.append(rect(8, y, SIDEBAR_IDEAL - 16, project_h, SELECTION, r=6))
    name_fill = PRIMARY
    key_fill = SECONDARY
    out.append(mark_tile(14, y + SIDEBAR_ROW_Y, MARK_SIDEBAR, INDIGO))
    out.append(text(14 + MARK_SIDEBAR + 10, y + project_h / 2 + BODY * 0.36, "Arkboard", BODY, name_fill))
    out.append(text(SIDEBAR_IDEAL - 16, y + project_h / 2 + MONO * 0.36, "ARK", MONO, key_fill, face=MONO_FACE, anchor="end"))

    foot = height - 40
    out.append(f'<line x1="0" y1="{foot:.1f}" x2="{SIDEBAR_IDEAL:.1f}" y2="{foot:.1f}" stroke="{HAIRLINE}" stroke-width="1"/>')
    out.append(glyph(24, foot + 20, 12, SECONDARY, 0.9))
    out.append(f'<circle cx="46" cy="{foot + 20:.1f}" r="3.5" fill="{MOSS}"/>')
    out.append(text(56, foot + 20 + CAPTION * 0.36, "Agents · :7420", CAPTION, SECONDARY))
    return out


def card(x, y, w, name, key, summary, brand, has_poster) -> tuple[list[str], float]:
    """A poster with a caption. No paths, no document words."""
    poster_h = w / CARD_POSTER_ASPECT
    out: list[str] = []
    if has_poster:
        # Stand-in for product/card.png: the real bytes are Riyu's generated art.
        out.append(f'<defs><linearGradient id="poster{int(x)}" x1="0" y1="0" x2="1" y2="1">'
                   f'<stop offset="0%" stop-color="#F3E9E2"/><stop offset="55%" stop-color="#CFC2F0"/>'
                   f'<stop offset="100%" stop-color="{brand}"/></linearGradient></defs>')
        out.append(rect(x, y, w, poster_h, f"url(#poster{int(x)})"))
        for i, inset in enumerate((0.30, 0.22, 0.14)):
            out.append(rect(x + w * inset, y + poster_h * (inset - 0.05), w * 0.52, poster_h * 0.62,
                            "#FFFFFF", r=18, opacity=0.20 + i * 0.10))
    else:
        out.append(rect(x, y, w, poster_h, blend(CARD_FILL, brand, 0.22)))
        out.append(glyph(x + w / 2, y + poster_h / 2, poster_h * 0.42, brand, 0.85))

    cy = y + poster_h + CARD_PAD
    out.append(text(x + CARD_PAD, cy + HEADING * 0.72, name, HEADING, PRIMARY, weight="600"))
    pin_x = x + w - CARD_PAD - 6
    out.append(
        f'<path d="M{pin_x - 4:.1f} {cy + 3:.1f} l8 0 l-3 5 l0 5 l-2 0 l0 -5 z" fill="{TERTIARY}"/>'
    )
    cy += HEADING + 3
    out.append(text(x + CARD_PAD, cy + CALLOUT * 0.72, summary, CALLOUT, SECONDARY))
    cy += CALLOUT + CARD_PAD

    height = cy - y
    out.insert(0, rect(x, y, w, height, CARD_FILL, r=RADIUS_CARD, stroke=CARD_STROKE))
    return out, height


TITLEBAR_H = 52.0


def window_chrome(width: float, title: str, subtitle: str, actions: str, title_x: float | None = None) -> list[str]:
    """Traffic lights plus the window title and subtitle. This is the only title."""
    out = [rect(0, 0, width, TITLEBAR_H, TITLEBAR)]
    out.append(f'<line x1="0" y1="{TITLEBAR_H}" x2="{width}" y2="{TITLEBAR_H}" stroke="{HAIRLINE}" stroke-width="1"/>')
    for i, colour in enumerate(("#FF5F57", "#FEBC2E", "#28C840")):
        out.append(f'<circle cx="{20 + i * 20}" cy="20" r="6" fill="{colour}"/>')
    tx = SIDEBAR_IDEAL + 24 if title_x is None else title_x
    out.append(text(tx, 22, title, BODY, PRIMARY, weight="600"))
    out.append(text(tx, 38, subtitle, CAPTION, SECONDARY))
    if "plus" in actions:
        out.append(text(width - 60, 26, "+", HEADING + 2, PRIMARY, anchor="middle"))
    out.append(rect(width - 34, 14, 16, 14, "none", r=3, stroke=PRIMARY, sw=1.2))
    return out


def project_home(width: float, height: float) -> list[str]:
    """The project page: a compact identity strip that never restates the name."""
    pane_x = SIDEBAR_IDEAL
    pane_w = width - pane_x
    out = [rect(0, 0, width, height, DOCUMENT_FIELD)]
    out.extend(window_chrome(width, "Arkboard", "Origin Ark", "", title_x=SIDEBAR_IDEAL + 24 + MARK_SIDEBAR + 44))
    out.append(f'<g transform="translate(0,{TITLEBAR_H})">' + "".join(sidebar(height - TITLEBAR_H, selected=2)) + "</g>")

    rose_pane = blend(DOCUMENT_FIELD, ROSE, 0.06)
    # Mark and key ride in the title bar beside the window title. No strip below.
    out.append(mark_tile(SIDEBAR_IDEAL + 24, 14, MARK_SIDEBAR, INDIGO))
    out.append(text(SIDEBAR_IDEAL + 24 + MARK_SIDEBAR + 8, 22, "ARK", MONO, SECONDARY, face=MONO_FACE))
    out.append(glyph(width - 60, 26, 12, SECONDARY, 0.85))
    y = TITLEBAR_H

    # Tab rail: native accessory-bar capsules on the glass layer, tinted by section.
    rail_h = BODY + 26
    out.append(rect(pane_x, y, pane_w, rail_h, blend("#FFFFFF", ROSE, 0.06)))
    tabs = [("Design", ROSE, True), ("Architecture", AZURE, False), ("Mockups", MAGENTA, False),
            ("Decisions & questions", GOLD, False), ("Issues", "#12908C", False), ("Timeline", MOSS, False)]
    tx = pane_x + PANE_X
    for label, hue, selected in tabs:
        w = len(label) * BODY * 0.54 + 34
        if selected:
            out.append(rect(tx, y + 6, w, rail_h - 12, blend("#FFFFFF", hue, 0.18), r=(rail_h - 12) / 2))
        out.append(glyph(tx + 15, y + rail_h / 2, 10, hue if selected else SECONDARY, 0.9))
        out.append(text(tx + 26, y + rail_h / 2 + BODY * 0.36, label, BODY, hue if selected else SECONDARY))
        tx += w + 6
    y += rail_h

    out.append(rect(pane_x, y, pane_w, height - y, rose_pane))
    dy = y + PANE_X
    for line in (
        "Arkboard is a reading room for a studio that is mostly documents.",
        "Colour lives in washes, chips, dots, and rules — the things you see",
        "without reading. Running prose is never tinted.",
    ):
        out.append(text(pane_x + PANE_X, dy + BODY * 0.72, line, BODY, PRIMARY))
        dy += BODY + 8
    return out


def render(path: Path) -> None:
    width, height = 1024.0, 588.0
    titlebar_h = TITLEBAR_H
    body: list[str] = [rect(0, 0, width, height, PANE)]

    body.extend(window_chrome(width, "Portfolio", "Origin Ark", "plus"))
    body.append(f'<g transform="translate(0,{titlebar_h})">' + "".join(sidebar(height - titlebar_h)) + "</g>")

    pane_x = SIDEBAR_IDEAL
    pane_w = width - pane_x
    body.append(rect(pane_x, titlebar_h, pane_w, height - titlebar_h, PANE))

    # LazyVGrid(.adaptive(minimum: 320, maximum: 480), spacing: 12) inside pane padding.
    avail = pane_w - PANE_X * 2
    columns = max(1, int((avail + CARD_GAP) // (CARD_MIN + CARD_GAP)))
    card_w = min(CARD_MAX, (avail - CARD_GAP * (columns - 1)) / columns)

    projects = [
        ("Arkboard", "ARK", "Origin Ark Studio's local studio board for macOS.", INDIGO, True),
        ("Lumen", "LUM", "Paints light for rooms that do not have any.", MAGENTA, False),
    ]

    cx0 = pane_x + PANE_X
    row_y = titlebar_h + PANE_X
    for start in range(0, len(projects), columns):
        row_h = 0.0
        for col, spec in enumerate(projects[start : start + columns]):
            name, key, summary, brand, has_poster = spec
            svg, height_used = card(
                cx0 + col * (card_w + CARD_GAP), row_y, card_w,
                name, key, summary, brand, has_poster,
            )
            body.extend(svg)
            row_h = max(row_h, height_used)
        row_y += row_h + CARD_GAP

    svg_text = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{height:.0f}" '
        f'viewBox="0 0 {width:.0f} {height:.0f}">' + "".join(body) + "</svg>"
    )
    svg_path = path.with_suffix(".svg")
    svg_path.write_text(svg_text)
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-z", "2", "-o", str(path), str(svg_path)], check=True)
        print(f"wrote {path}")
        return
    try:
        import cairosvg  # type: ignore

        cairosvg.svg2png(url=str(svg_path), write_to=str(path), scale=2)
        print(f"wrote {path}")
    except ImportError:
        print(f"wrote {svg_path} (install librsvg2-bin or cairosvg for a PNG)")


def write(path: Path, width: float, height: float, body: list[str]) -> None:
    svg_text = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{height:.0f}" '
        f'viewBox="0 0 {width:.0f} {height:.0f}">' + "".join(body) + "</svg>"
    )
    svg_path = path.with_suffix(".svg")
    svg_path.write_text(svg_text)
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-z", "2", "-o", str(path), str(svg_path)], check=True)
        print(f"wrote {path}")
        return
    try:
        import cairosvg  # type: ignore

        cairosvg.svg2png(url=str(svg_path), write_to=str(path), scale=2)
        print(f"wrote {path}")
    except ImportError:
        print(f"wrote {svg_path} (install librsvg2-bin or cairosvg for a PNG)")


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build" / "preview"
    out_dir.mkdir(parents=True, exist_ok=True)
    render(out_dir / "portfolio_shell.png")
    write(out_dir / "project_home_shell.png", 1024.0, 588.0, project_home(1024.0, 588.0))


if __name__ == "__main__":
    main()
