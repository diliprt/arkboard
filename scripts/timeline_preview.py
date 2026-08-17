#!/usr/bin/env python3
"""Draw the Timeline Gantt's layout on a Linux host, where the app cannot be built.

Every coordinate comes from the mirrored maths in spec_check.py — the same column, window, bar
and link maths that gantt_check.sh pins against the shipping Swift — and every size and colour
is copied from Typography.swift and Hue.swift. It is enough to see whether the chart reads:
row order, bar spans, dependency links, the Today rule, and how the axis behaves at each scale.

    python3 scripts/timeline_preview.py [output-dir]

It is a geometry preview, not a screenshot. Text metrics, materials, and SF Symbols are the real
app's; verify the finished screen on a Mac with ./scripts/run.sh.
"""
from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("spec_check", ROOT / "scripts" / "spec_check.py")
sc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sc)

# Metrics from Sources/Arkboard/UI/Theme/Typography.swift
LABEL_COL = 240.0
AXIS_H = 44.0
TODAY_TIER = 24.0
PROJECT_ROW = 34.0
MILESTONE_ROW = 28.0
PROJECT_BAR = 14.0
MILESTONE_BAR = 8.0
DIAMOND = 10.0
BAR_MIN = 10.0
ELBOW = 10.0
CHIP_X = 10.0
PANE_X = 24.0
PANE_Y = 20.0

# Hue light values from Sources/Arkboard/UI/Theme/Hue.swift
MOSS = "#1F8F63"
GOLD = "#A87908"
CRIMSON = "#C0392B"
SLATE = "#6E7781"
INDIGO = "#5A62D6"

WINDOW_BG = "#ECECEC"
CARD = "#FFFFFF"
HAIRLINE = "#D5D5D5"
PRIMARY = "#000000"
SECONDARY = "#777777"
TERTIARY = "#AAAAAA"

STATUS_HUE = {"done": MOSS, "in_progress": GOLD, "missed": CRIMSON, "planned": SLATE}
FACE = "DejaVu Sans, Helvetica, Arial, sans-serif"

NOW = (2026, 8, 15)

PROJECTS = [
    {"id": "p-ark", "key": "ARK", "name": "Arkboard", "color": INDIGO},
    {"id": "p-lum", "key": "LUM", "name": "Lumen", "color": MOSS},
    {"id": "p-atl", "key": "ATL", "name": "Atlas", "color": "#C2661F"},
]

MILESTONES = [
    {"id": "m-pack", "projectId": "p-ark", "title": "Design pack locked",
     "targetDate": (2026, 8, 20), "status": "done"},
    {"id": "m-gantt", "projectId": "p-ark", "title": "Timeline is a Gantt",
     "targetDate": (2026, 9, 18), "status": "in_progress", "dependsOn": ["m-pack"]},
    {"id": "m-glass", "projectId": "p-ark", "title": "Liquid Glass chrome",
     "targetDate": (2026, 10, 9), "status": "planned", "dependsOn": ["m-gantt"]},
    {"id": "m-v3", "projectId": "p-ark", "title": "Studio board v3",
     "targetDate": (2026, 11, 6), "status": "planned", "dependsOn": ["m-glass", "m-gantt"]},
    {"id": "m-colour", "projectId": "p-lum", "title": "Colour engine spec",
     "targetDate": (2026, 9, 4), "status": "planned"},
    {"id": "m-render", "projectId": "p-lum", "title": "First render",
     "targetDate": (2026, 10, 23), "status": "planned", "dependsOn": ["m-colour"]},
    {"id": "m-model", "projectId": "p-atl", "title": "Data model review",
     "targetDate": (2026, 8, 7), "status": "missed"},
    {"id": "m-ingest", "projectId": "p-atl", "title": "Ingest pipeline",
     "targetDate": (2026, 9, 30), "status": "planned", "dependsOn": ["m-model"]},
    {"id": "m-review", "projectId": None, "title": "Q4 studio review",
     "targetDate": (2026, 10, 16), "status": "planned"},
]

EVENTS = [
    {"id": "i-11", "projectId": "p-ark", "identifier": "ARK-11", "date": (2026, 7, 28)},
    {"id": "i-14", "projectId": "p-ark", "identifier": "ARK-14", "date": (2026, 8, 12)},
    {"id": "i-16", "projectId": "p-ark", "identifier": "ARK-16", "date": (2026, 8, 4)},
    {"id": "i-3", "projectId": "p-atl", "identifier": "ATL-3", "date": (2026, 7, 30)},
]

STATUS_BY_ID = {m["id"]: m.get("status", "planned") for m in MILESTONES}
TITLE_BY_ID = {m["id"]: m["title"] for m in MILESTONES}
COLOR_BY_ID = {p["id"]: p["color"] for p in PROJECTS}


def esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def row_height(row: dict) -> float:
    return PROJECT_ROW if row["kind"] == "project" else MILESTONE_ROW


def bar_colour(row: dict) -> str:
    if row["kind"] == "milestone":
        return STATUS_HUE[STATUS_BY_ID[row["id"]]]
    return COLOR_BY_ID.get(row["id"], SLATE)


def date_caption(value: tuple) -> str:
    return f"{value[2]} {sc.MONTH_ABBR[value[1] - 1]}"


def panel(plan: dict, pane_width: float, caption: str) -> tuple[list[str], float]:
    """One Timeline pane: scale control, axis, rows, bars, links. Returns (svg, height)."""
    scale = plan["scale"]
    start, end = plan["window"]
    columns = sc.gantt_columns(start, end, scale)
    # The Swift viewport is the chart HStack width: the pane minus its horizontal padding.
    content_width = pane_width - 2 * PANE_X
    column_width = sc.gantt_column_width(content_width, len(columns), scale)
    plot_width = column_width * len(columns)
    scrolls = sc.gantt_scrolls(content_width, len(columns), scale)
    visible_plot = min(plot_width, content_width - LABEL_COL)

    rows = plan["rows"]
    body_height = sum(row_height(r) for r in rows)
    control_h = 30.0
    header_h = 62.0
    height = header_h + PANE_Y + control_h + 14 + AXIS_H + body_height + PANE_Y

    out: list[str] = []
    out.append(f'<rect width="{pane_width}" height="{height}" fill="{WINDOW_BG}"/>')
    # Screen header: section symbol, title, subtitle, hue divider.
    out.append(f'<rect x="0" y="0" width="{pane_width}" height="{header_h}" fill="{WINDOW_BG}"/>')
    for i, w in enumerate((5, 11, 7, 13)):
        out.append(
            f'<rect x="{PANE_X + i * 5}" y="{34 - w}" width="3.2" height="{w}" rx="1" fill="{MOSS}"/>'
        )
    out.append(
        f'<text x="{PANE_X + 30}" y="34" font-family="{FACE}" font-size="19" font-weight="600" '
        f'fill="{PRIMARY}">Timeline</text>'
    )
    out.append(
        f'<text x="{PANE_X}" y="52" font-family="{FACE}" font-size="12" fill="{SECONDARY}">'
        f'{esc(caption)}</text>'
    )
    out.append(
        f'<rect x="0" y="{header_h - 1}" width="{pane_width}" height="1" fill="{MOSS}" fill-opacity="0.22"/>'
    )
    # Section wash under the header.
    out.append(
        f'<rect x="0" y="{header_h}" width="{pane_width}" height="{height - header_h}" '
        f'fill="{MOSS}" fill-opacity="0.06"/>'
    )

    # Scale control — the one control on this screen.
    cx, cy = PANE_X, header_h + PANE_Y
    seg = 260 / 3
    out.append(
        f'<rect x="{cx}" y="{cy}" width="260" height="{control_h}" rx="6" fill="{CARD}" '
        f'stroke="{HAIRLINE}"/>'
    )
    for i, name in enumerate(("Week", "Month", "Year")):
        selected = name.lower() == scale
        if selected:
            out.append(
                f'<rect x="{cx + i * seg + 2}" y="{cy + 2}" width="{seg - 4}" height="{control_h - 4}" '
                f'rx="4" fill="{CARD}" stroke="{HAIRLINE}"/>'
            )
        else:
            out.append(
                f'<rect x="{cx + i * seg}" y="{cy}" width="{seg}" height="{control_h}" fill="{WINDOW_BG}" '
                f'fill-opacity="0.6"/>'
            )
        out.append(
            f'<text x="{cx + i * seg + seg / 2}" y="{cy + control_h / 2 + 4}" text-anchor="middle" '
            f'font-family="{FACE}" font-size="12" font-weight="{"600" if selected else "400"}" '
            f'fill="{PRIMARY if selected else SECONDARY}">{name}</text>'
        )
    if scrolls:
        out.append(
            f'<text x="{cx + 274}" y="{cy + control_h / 2 + 4}" font-family="{FACE}" font-size="11" '
            f'fill="{TERTIARY}">axis scrolls horizontally at this scale</text>'
        )

    chart_y = cy + control_h + 14
    plot_x = PANE_X + LABEL_COL
    clip = f'clip-{scale}-{int(pane_width)}-{len(rows)}'
    out.append(
        f'<clipPath id="{clip}"><rect x="{plot_x}" y="{chart_y}" width="{visible_plot}" '
        f'height="{AXIS_H + body_height}"/></clipPath>'
    )
    out.append(f'<g clip-path="url(#{clip})">')

    # Axis: one label per column, on a hairline.
    for index, column in enumerate(columns):
        x = plot_x + index * column_width
        out.append(
            f'<text x="{x + 4}" y="{chart_y + AXIS_H - 7}" font-family="{FACE}" font-size="11" '
            f'font-weight="500" fill="{SECONDARY}">{sc.gantt_column_label(*column, scale)}</text>'
        )
        if index:
            out.append(
                f'<rect x="{x}" y="{chart_y + TODAY_TIER}" width="1" height="{AXIS_H - TODAY_TIER}" '
                f'fill="{HAIRLINE}" fill-opacity="0.6"/>'
            )
        if index:
            out.append(
                f'<rect x="{x}" y="{chart_y + AXIS_H}" width="1" height="{body_height}" '
                f'fill="{HAIRLINE}" fill-opacity="0.6"/>'
            )
    out.append(
        f'<rect x="{plot_x}" y="{chart_y + AXIS_H - 1}" width="{visible_plot}" height="1" fill="{HAIRLINE}"/>'
    )

    body_y = chart_y + AXIS_H

    def px(point: tuple) -> float:
        return plot_x + sc.gantt_fraction(point, start, end, scale) * plot_width

    # One Today rule for the whole chart.
    today_x = px(NOW)
    out.append(
        f'<rect x="{today_x}" y="{body_y}" width="1" height="{body_height}" fill="{MOSS}" fill-opacity="0.55"/>'
    )
    flag_x = min(max(plot_x, today_x - CHIP_X), plot_x + visible_plot - 60)
    out.append(
        f'<rect x="{flag_x}" y="{chart_y + 1}" width="55" height="21" rx="10.5" '
        f'fill="{MOSS}" fill-opacity="0.12"/>'
    )
    out.append(
        f'<text x="{flag_x + CHIP_X}" y="{chart_y + 15}" font-family="{FACE}" font-size="11" '
        f'font-weight="500" fill="{MOSS}">Today</text>'
    )

    centres: dict[str, float] = {}
    y = body_y
    for row in rows:
        centres[row["id"]] = y + row_height(row) / 2
        y += row_height(row)

    # Dependency links run behind the bars.
    by_id = {r["id"]: r for r in rows}
    for link in plan["links"]:
        src, dst = link.split("->")
        x1, y1 = px(by_id[src]["marker"]), centres[src]
        x2, y2 = px(by_id[dst]["start"]), centres[dst]
        elbow = x2 - ELBOW if x2 > x1 + 2 * ELBOW else x1 + ELBOW
        out.append(
            f'<path d="M {x1} {y1} L {elbow} {y1} L {elbow} {y2} L {x2} {y2}" fill="none" '
            f'stroke="{SLATE}" stroke-opacity="0.6" stroke-linecap="round"/>'
        )
        out.append(
            f'<path d="M {x2 - 4} {y2 - 3} L {x2} {y2} L {x2 - 4} {y2 + 3}" fill="none" '
            f'stroke="{SLATE}" stroke-opacity="0.6" stroke-linecap="round"/>'
        )

    # Bars.
    y = body_y
    for row in rows:
        h = row_height(row)
        colour = bar_colour(row)
        x1, x2 = px(row["start"]), px(row["end"])
        width = max(BAR_MIN, x2 - x1)
        if row["kind"] == "project":
            top = y + (h - PROJECT_BAR) / 2
            out.append(
                f'<rect x="{x1}" y="{top}" width="{width}" height="{PROJECT_BAR}" rx="{PROJECT_BAR / 2}" '
                f'fill="{colour}" fill-opacity="0.30" stroke="{colour}" stroke-opacity="0.55"/>'
            )
            for mark in row["marks"]:
                mx = px(next(e["date"] for e in EVENTS if e["id"] == mark))
                out.append(
                    f'<circle cx="{mx}" cy="{y + h / 2}" r="2.5" fill="{MOSS}" fill-opacity="0.75"/>'
                )
        else:
            top = y + (h - MILESTONE_BAR) / 2
            out.append(
                f'<rect x="{x1}" y="{top}" width="{width}" height="{MILESTONE_BAR}" '
                f'rx="{MILESTONE_BAR / 2}" fill="{colour}" fill-opacity="0.45"/>'
            )
            out.append(
                f'<rect x="{x2 - DIAMOND / 2}" y="{y + h / 2 - DIAMOND / 2}" width="{DIAMOND}" '
                f'height="{DIAMOND}" fill="{colour}" '
                f'transform="rotate(45 {x2} {y + h / 2})"/>'
            )
        y += h
    out.append("</g>")

    # Row labels, pinned left of the axis.
    label_clip = f'labels-{scale}-{int(pane_width)}-{len(rows)}'
    out.append(
        f'<clipPath id="{label_clip}"><rect x="{PANE_X}" y="{body_y}" width="{LABEL_COL - 12}" '
        f'height="{body_height}"/></clipPath>'
    )
    out.append(f'<g clip-path="url(#{label_clip})">')
    y = body_y
    for row in rows:
        h = row_height(row)
        baseline = y + h / 2 + 4
        if row["kind"] == "project":
            colour = bar_colour(row)
            out.append(
                f'<rect x="{PANE_X}" y="{y + h / 2 - 8}" width="16" height="16" rx="5" fill="{colour}" '
                f'fill-opacity="0.16"/>'
            )
            out.append(
                f'<rect x="{PANE_X + 4}" y="{y + h / 2 - 4}" width="8" height="8" rx="2" fill="{colour}"/>'
            )
            out.append(
                f'<text x="{PANE_X + 22}" y="{baseline}" font-family="{FACE}" font-size="13" '
                f'font-weight="600" fill="{PRIMARY}">{esc(row["title"])}</text>'
            )
            if row["milestoneCount"]:
                out.append(
                    f'<text x="{PANE_X + LABEL_COL - 24}" y="{baseline}" text-anchor="end" '
                    f'font-family="{FACE}" font-size="11" font-weight="500" fill="{TERTIARY}">'
                    f'{row["milestoneCount"]}</text>'
                )
        else:
            out.append(
                f'<text x="{PANE_X + 18}" y="{baseline}" font-family="{FACE}" font-size="13" '
                f'fill="{PRIMARY}">{esc(row["title"])}</text>'
            )
            out.append(
                f'<text x="{PANE_X + LABEL_COL - 24}" y="{baseline}" text-anchor="end" '
                f'font-family="{FACE}" font-size="11" font-weight="500" fill="{SECONDARY}">'
                f'{date_caption(row["end"])}</text>'
            )
        y += h
    out.append("</g>")
    return out, height


def write(path: Path, panels: list[tuple[dict, float, str]], gap: float = 0.0) -> None:
    body: list[str] = []
    total = 0.0
    width = max(p[1] for p in panels)
    for index, (plan, pane_width, caption) in enumerate(panels):
        svg, height = panel(plan, pane_width, caption)
        body.append(f'<g transform="translate(0,{total})">' + "".join(svg) + "</g>")
        total += height
        if index < len(panels) - 1:
            body.append(
                f'<rect x="0" y="{total}" width="{width}" height="{gap}" fill="#DDDDDD"/>'
            )
            total += gap
    svg_text = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{total}" '
        f'viewBox="0 0 {width} {total}">' + "".join(body) + "</svg>"
    )
    svg_path = path.with_suffix(".svg")
    svg_path.write_text(svg_text)
    if shutil.which("rsvg-convert") is None:
        print(f"wrote {svg_path} (install librsvg2-bin for a PNG)")
        return
    subprocess.run(["rsvg-convert", "-z", "2", "-o", str(path), str(svg_path)], check=True)
    print(f"wrote {path}")


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build" / "timeline-preview"
    out_dir.mkdir(parents=True, exist_ok=True)

    master_month = sc.gantt_plan(PROJECTS, MILESTONES, EVENTS, scope=None, scale="month", now=NOW)
    master_year = sc.gantt_plan(PROJECTS, MILESTONES, EVENTS, scope=None, scale="year", now=NOW)
    scoped = sc.gantt_plan(PROJECTS, MILESTONES, EVENTS, scope="p-ark", scale="month", now=NOW)

    print("master month rows:", [f'{r["kind"]}:{r["id"]}' for r in master_month["rows"]])
    print("master month links:", master_month["links"])
    print("window:", master_month["window"],
          "columns:", [sc.gantt_column_label(*c, "month") for c in
                       sc.gantt_columns(*master_month["window"], "month")])
    print("scoped rows:", [r["id"] for r in scoped["rows"]], "links:", scoped["links"])

    write(
        out_dir / "timeline_master_gantt_month.png",
        [(master_month, 1088.0, "Every project on one timeline.")],
    )
    write(
        out_dir / "timeline_project_tab_and_year_scale.png",
        [
            (scoped, 1088.0, "Arkboard's Timeline tab — the same Gantt, scoped to one project."),
            (master_year, 1088.0, "The master Timeline at Year scale — same shape, coarser axis."),
        ],
        gap=10.0,
    )


if __name__ == "__main__":
    main()
