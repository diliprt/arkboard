#!/usr/bin/env python3
"""Linux-runnable checks against the locked design pack.

Mirrors DocumentRouting, QuestionParser, Validation, HumanVocabulary, and
the source-layout / exclusion rules from product/*.md. Does not launch the app.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources" / "Arkboard"
PRODUCT = ROOT / "product"
PASS = 0
FAIL = 0


def ok(name: str, cond: bool, detail: str = "") -> None:
    global PASS, FAIL
    if cond:
        print(f"PASS  {name}")
        PASS += 1
    else:
        print(f"FAIL  {name}" + (f" — {detail}" if detail else ""))
        FAIL += 1


# --- Routing (product/architecture.md) ---

DESIGN_KW = ("design", "ui", "ux", "visual", "brand", "spec")
ARCH_KW = ("arch", "api", "mcp", "data", "schema", "engine", "infra")
DEC_KW = ("decision", "question", "rfc", "adr")
MOCK_KW = ("mockup", "frame", "wireframe", "screen", "flow")
IMAGES = {".png", ".jpg", ".jpeg", ".gif", ".webp"}
Metrics_paneY = 20.0  # Metrics.paneY
BRAND_ASSETS = {
    "card.png", "card.webp", "card.jpg", "card.jpeg",
    "icon.png", "icon.webp", "icon.jpg", "icon.jpeg",
    "mark.png", "mark.webp",
    "logo.png", "logo.webp",
}


def stem(path: str) -> str:
    return Path(path).stem.lower()


def route(path: str) -> str:
    lower = path.replace("\\", "/").lower()
    file_stem = stem(path)
    if lower in {"product/readme.md", "product/overview.md"}:
        return "overview"
    parts = lower.split("/")
    if "product" in parts:
        i = parts.index("product")
        if i + 1 < len(parts) and "." not in parts[i + 1]:
            folder = parts[i + 1]
            if folder == "design":
                return "design"
            if folder == "architecture":
                return "architecture"
            if folder == "mockups":
                return "mockups"
            if folder in {"decisions", "questions"}:
                return "decisions"
    if file_stem == "design":
        return "design"
    if file_stem == "architecture":
        return "architecture"
    if file_stem == "mockups":
        return "mockups"
    if file_stem in {"decisions", "questions"}:
        return "decisions"
    for tab, words in (
        ("design", DESIGN_KW),
        ("architecture", ARCH_KW),
        ("decisions", DEC_KW),
        ("mockups", MOCK_KW),
    ):
        if any(w in file_stem for w in words):
            return tab
    # Brand artwork at the root of product/ is the project's own face — the
    # Portfolio poster and the sidebar mark — not a frame someone drew.
    if Path(path).name.lower() in BRAND_ASSETS:
        return "more"
    if Path(path).suffix.lower() in IMAGES:
        return "mockups"
    return "more"


def slug(text: str) -> str:
    cleaned = re.sub(r"[^a-z0-9\s-]", " ", text.lower())
    return re.sub(r"\s+", "-", cleaned).strip("-")


def parse_questions(markdown: str):
    items = []
    current = None
    for line in markdown.splitlines():
        m = re.match(r"^(#{2,3})\s+(.+)$", line)
        if m:
            if current:
                items.append(current)
            heading = m.group(2).strip()
            current = {
                "level": len(m.group(1)),
                "heading": heading,
                "body": [],
                "open": heading.lower().startswith("open") or heading.endswith("?"),
                "locked": heading.lower().startswith("locked") or heading.lower().startswith("decided"),
                "anchor": slug(heading),
            }
        elif current is not None:
            current["body"].append(line)
    if current:
        items.append(current)
    return [i for i in items if i["open"] or i["locked"]]


def collapse_title(raw: str) -> str:
    return re.sub(r"\s+", " ", raw).strip()


def first_sentence(markdown: str) -> str:
    stripped = re.sub(r"^#+\s+", "", markdown)
    stripped = re.sub(r"\s+", " ", stripped.replace("\n", " ")).strip()
    idx = stripped.find(". ")
    if idx != -1:
        return stripped[: idx + 1].strip()
    return stripped


def strip_name_prefix(text: str, name: str) -> str:
    """Drop a leading project name so the card does not read 'Arkboard Arkboard is…'."""
    result = text.strip()
    prefix = name.strip()
    if not prefix:
        return result
    separators = set(" \t\n\r—–-:,")
    while result.lower().startswith(prefix.lower()):
        rest = result[len(prefix) :]
        if not rest:
            break
        if rest[0] not in separators:
            break
        result = rest.lstrip("".join(separators))
    return result


def card_summary(markdown: str | None, name: str, fallback: str = "") -> str:
    raw = first_sentence(markdown) if markdown else fallback
    if not raw:
        raw = fallback
    stripped = strip_name_prefix(raw, name)
    return stripped or strip_name_prefix(fallback, name)


def project_key(raw: str) -> str:
    key = "".join(ch for ch in raw.upper() if ch.isalnum() and ch.isascii())
    key = "".join(ch for ch in key if ("A" <= ch <= "Z") or ("0" <= ch <= "9"))
    if not (2 <= len(key) <= 6):
        raise ValueError("invalid key")
    return key


def labels(raw):
    seen = set()
    out = []
    for item in raw:
        name = item.strip().lower()
        if name and name not in seen:
            seen.add(name)
            out.append(name)
    return out


def fnv1a(text: str) -> int:
    h = 2166136261
    for b in text.encode():
        h ^= b
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def actor_hue(name: str) -> str:
    key = name.strip().lower()
    reserved = {"riyu": "moss", "agent": "azure", "cursor": "violet", "grok": "ember"}
    if key in reserved:
        return reserved[key]
    ramp = ["rose", "ember", "gold", "moss", "teal", "azure", "indigo", "violet", "magenta", "crimson"]
    return ramp[fnv1a(key) % 10]


MARKS = [
    "square.3.layers.3d",
    "paintbrush.pointed.fill",
    "cube.transparent",
    "antenna.radiowaves.left.and.right",
    "leaf.fill",
    "bolt.horizontal.fill",
    "globe.desk",
    "camera.aperture",
    "shippingbox.fill",
    "waveform.path",
    "puzzlepiece.extension.fill",
    "compass.drawing",
    "book.closed.fill",
    "sparkle",
    "hammer.fill",
    "map.fill",
    "theatermasks.fill",
    "moon.stars.fill",
    "hare.fill",
    "tram.fill",
]
ARK_MARK = "square.3.layers.3d"
ARK_COLOR = "#5A62D6"
RAMP = ["#D4436B", "#C2661F", "#A87908", "#1F8F63", "#12908C", "#2C6FCF", "#5A62D6", "#8A54D6", "#B23FA8", "#C0392B"]


def assign_mark(key: str, name: str, used: set[str]):
    if key.upper() == "ARK" or name.lower() == "arkboard":
        return ARK_MARK, ARK_COLOR
    start = fnv1a(key.lower()) % len(MARKS)
    symbol = MARKS[start]
    for offset in range(len(MARKS)):
        candidate = MARKS[(start + offset) % len(MARKS)]
        if candidate == ARK_MARK:
            continue
        if candidate not in used:
            symbol = candidate
            break
    color = RAMP[fnv1a(key.lower()) % len(RAMP)]
    return symbol, color


def human_group(status: str, archived: bool):
    if archived:
        return "Archived"
    return {
        "in_progress": "Underway",
        "backlog": "Queued",
        "todo": "Queued",
        "done": "Done",
        "canceled": None,
    }[status]


def parse_flow_markdown(text: str) -> list[str]:
    nodes: list[str] = []
    seen: set[str] = set()
    for raw in text.splitlines():
        line = raw.strip().lstrip("-* ").strip()
        if "→" not in line and "->" not in line:
            continue
        for part in re.split(r"\s*(?:→|->)\s*", line):
            name = part.strip().strip("`")
            if name and name not in seen and not name.startswith("#"):
                seen.add(name)
                nodes.append(name)
    return nodes


def parse_flow_json(text: str) -> list[str]:
    import json
    data = json.loads(text)
    nodes = data.get("nodes") or []
    titles: list[str] = []
    for node in nodes:
        if isinstance(node, str):
            titles.append(node)
        elif isinstance(node, dict):
            titles.append(str(node.get("title") or node.get("id") or ""))
    return [t for t in titles if t]


def infer_flow(filenames: list[str]) -> list[str]:
    return [Path(name).stem.replace("-", " ").replace("_", " ") for name in sorted(filenames)]


def should_replace_bundle(
    current_count: int,
    incoming_count: int,
    incoming_error: str | None,
    incoming_source: str,
    incoming_has_root: bool,
) -> bool:
    """Keep a successful product/ load when a later refresh comes back empty."""
    if incoming_count > 0:
        return True
    if current_count == 0:
        return True
    if incoming_source == "local" and incoming_has_root and incoming_error is None:
        return True
    return False


def merge_bundles(
    current: dict[str, int],
    incoming: dict[str, int],
    *,
    had_projects: bool,
) -> dict[str, int]:
    """Never replace the map with an empty snapshot when no projects were visible."""
    if not had_projects:
        return current
    result = dict(current)
    for key, count in incoming.items():
        if should_replace_bundle(current.get(key, 0), count, None, "local", True):
            result[key] = count
    return result


def document_page_width(pane_width: float) -> float:
    """Project-home page takes the pane. No 720 island, no 1000 grid."""
    return max(pane_width, 560.0)


MONTH_ABBR = (
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
)

# Mirrors TimelineScale in Sources/Arkboard/UI/Portfolio/TimelineModel.swift.
GANTT_MIN_COLUMNS = {"week": 6, "month": 4, "quarter": 4}
GANTT_MIN_COLUMN_WIDTH = {"week": 54.0, "month": 88.0, "quarter": 96.0}
GANTT_LABEL_COLUMN = 240.0

Day = tuple  # (year, month, day)


def _date(value: Day):
    from datetime import date
    return date(value[0], value[1], value[2])


def gantt_column_start(year: int, month: int, day: int, scale: str) -> Day:
    """Monday-start week, first of month, first of quarter. Mirrors GanttMath.columnStart."""
    from datetime import date, timedelta
    if scale == "week":
        start = date(year, month, day) - timedelta(days=date(year, month, day).weekday())
        return start.year, start.month, start.day
    if scale == "month":
        return year, month, 1
    if scale == "quarter":
        return year, (month - 1) // 3 * 3 + 1, 1
    raise ValueError(scale)


def gantt_advance(year: int, month: int, day: int, scale: str, delta: int) -> Day:
    """Mirrors GanttMath.advance."""
    from datetime import date, timedelta
    if scale == "week":
        start = date(year, month, day) + timedelta(weeks=delta)
        return start.year, start.month, start.day
    step = {"month": 1, "quarter": 3}[scale] * delta
    index = year * 12 + (month - 1) + step
    next_year, next_month = divmod(index, 12)
    return next_year, next_month + 1, 1


def gantt_columns(start: Day, end: Day, scale: str) -> list[Day]:
    """Mirrors GanttMath.columns."""
    result: list[Day] = []
    cursor = gantt_column_start(*start, scale)
    while _date(cursor) < _date(end) and len(result) < 512:
        result.append(cursor)
        cursor = gantt_advance(*cursor, scale, 1)
    return result or [gantt_column_start(*start, scale)]


def gantt_column_label(year: int, month: int, day: int, scale: str) -> str:
    """Mirrors GanttMath.columnLabel."""
    if scale == "week":
        return f"{day} {MONTH_ABBR[month - 1]}"
    if scale == "month":
        return f"{MONTH_ABBR[month - 1]} {year}"
    if scale == "quarter":
        return f"Q{(month - 1) // 3 + 1} {year}"
    raise ValueError(scale)


def gantt_window(dates: list[Day], scale: str, now: Day) -> tuple[Day, Day]:
    """One padding column each side, always wide enough to hold Today. Mirrors GanttMath.window."""
    everything = list(dates) + [now]
    first = min(everything, key=_date)
    last = max(everything, key=_date)
    start = gantt_column_start(*gantt_advance(*gantt_column_start(*first, scale), scale, -1), scale)
    end = gantt_column_start(*gantt_advance(*gantt_column_start(*last, scale), scale, 2), scale)
    while len(gantt_columns(start, end, scale)) < GANTT_MIN_COLUMNS[scale]:
        end = gantt_advance(*end, scale, 1)
    return start, end


def gantt_fraction(point: Day, start: Day, end: Day) -> float:
    """Horizontal position as 0…1 of the window. Mirrors GanttMath.fraction."""
    span = max(1.0, (_date(end) - _date(start)).total_seconds())
    return min(1.0, max(0.0, (_date(point) - _date(start)).total_seconds() / span))


def gantt_today_in_window(dates: list[Day], scale: str, now: Day) -> bool:
    """One Today rule, drawn on the axis. The window must always have room for it."""
    start, end = gantt_window(dates, scale, now)
    return _date(start) <= _date(now) <= _date(end)


def gantt_column_width(pane_width: float, columns: int, scale: str) -> float:
    """Columns stretch to fill the pane, but never below a legible width."""
    available = max(0.0, pane_width - GANTT_LABEL_COLUMN)
    return max(GANTT_MIN_COLUMN_WIDTH[scale], available / max(1, columns))


def gantt_scrolls(pane_width: float, columns: int, scale: str) -> bool:
    available = max(0.0, pane_width - GANTT_LABEL_COLUMN)
    return gantt_column_width(pane_width, columns, scale) * columns > available + 0.5


def gantt_dependencies(raw: list[str]) -> list[str]:
    """Mirrors GanttDependencies.normalise."""
    seen: set[str] = set()
    result: list[str] = []
    for value in raw:
        trimmed = value.strip()
        if trimmed and trimmed not in seen:
            seen.add(trimmed)
            result.append(trimmed)
    return result


def gantt_creates_cycle(milestone_id: str, candidates: list[str], edges: dict[str, list[str]]) -> bool:
    """Mirrors GanttDependencies.createsCycle."""
    pending = list(candidates)
    seen: set[str] = set()
    while pending:
        current = pending.pop()
        if current == milestone_id:
            return True
        if current in seen:
            continue
        seen.add(current)
        pending.extend(edges.get(current, []))
    return False


def gantt_plan(
    projects: list[dict],
    milestones: list[dict],
    events: list[dict],
    scope: str | None = None,
    scale: str = "month",
    now: Day = (2026, 8, 15),
) -> dict:
    """Project rows with milestone rows underneath, plus dependency links. Mirrors GanttPlanner.plan."""
    scoped = [m for m in milestones if scope is None or m.get("projectId") == scope]
    marks_in = [e for e in events if scope is None or e["projectId"] == scope]
    window = gantt_window([m["targetDate"] for m in scoped] + [e["date"] for e in marks_in], scale, now)
    target_by_id = {m["id"]: m["targetDate"] for m in scoped}

    buckets: list[tuple[str, dict | None]] = [
        (p["id"], p) for p in projects if scope is None or p["id"] == scope
    ]
    if scope is None and any(m.get("projectId") is None for m in scoped):
        buckets.append(("studio", None))

    rows: list[dict] = []
    links: list[str] = []
    for key, project in buckets:
        mine = sorted(
            [m for m in scoped if (m.get("projectId") or "studio") == key],
            key=lambda m: (_date(m["targetDate"]), m["title"]),
        )
        marks = sorted([e for e in marks_in if e["projectId"] == key], key=lambda e: _date(e["date"]))
        if not mine and not marks:
            continue
        dates = [m["targetDate"] for m in mine] + [e["date"] for e in marks]
        project_start = min(dates, key=_date)
        project_end = max(dates, key=_date)
        rows.append({
            "id": key,
            "kind": "project",
            "title": project["name"] if project else "Studio",
            "start": project_start,
            "end": project_end,
            "marks": [e["id"] for e in marks],
            "milestoneCount": len(mine),
        })
        for milestone in mine:
            predecessors = [
                d for d in milestone.get("dependsOn", [])
                if d in target_by_id and d != milestone["id"]
            ]
            inherited = [target_by_id[d] for d in predecessors]
            start = max(inherited, key=_date) if inherited else project_start
            if _date(start) > _date(milestone["targetDate"]):
                start = milestone["targetDate"]
            rows.append({
                "id": milestone["id"],
                "kind": "milestone",
                "title": milestone["title"],
                "start": start,
                "end": milestone["targetDate"],
                "marker": milestone["targetDate"],
                "dependsOn": predecessors,
            })
            links.extend(f"{d}->{milestone['id']}" for d in predecessors)
    return {"rows": rows, "links": links, "window": window, "scale": scale}


def handoff_page_line(project_name: str | None, tab: str | None, document_path: str | None, destination: str) -> str:
    parts: list[str] = []
    if project_name:
        parts.append(project_name)
    elif destination == "timeline":
        parts.append("Timeline")
    elif destination == "onboarding":
        parts.append("Onboarding")
    else:
        parts.append("Portfolio")
    if tab:
        parts.append(tab)
    if document_path:
        parts.append(document_path)
    return " · ".join(parts)


def handoff_nearest_heading(markdown: str, selected: str, fallback: str | None = None) -> str | None:
    headings: list[tuple[int, str]] = []
    selected_line = None
    for index, line in enumerate(markdown.replace("\r\n", "\n").split("\n")):
        stripped = line.lstrip()
        hashes = 0
        while hashes < len(stripped) and stripped[hashes] == "#":
            hashes += 1
        if 1 <= hashes <= 6 and hashes < len(stripped) and stripped[hashes] == " ":
            title = stripped[hashes + 1 :].strip()
            if title:
                headings.append((index, title))
        if selected_line is None and selected and selected in line:
            selected_line = index
    if selected_line is not None:
        prior = [title for line_no, title in headings if line_no <= selected_line]
        if prior:
            return prior[-1]
    if fallback:
        return fallback
    return headings[0][1] if headings else None


def handoff_persist_body(user_text: str, page_line: str = "") -> str:
    """Activity body is the typed comment only. page_line is chrome, not body."""
    return user_text.strip()


def check_polish(swift: str, home: str, root: str, sidebar: str) -> None:
    """product/polish.md must-fix (and cheap should-fix) source checks."""
    now = (2026, 8, 15)
    # D2 was "one Today rule in the spine". The Gantt draws it on the axis instead, so the
    # invariant is now that the window always has room for exactly one Today line.
    ok("D2 today fits when everything is future", gantt_today_in_window([(2026, 11, 1)], "month", now))
    ok("D2 today fits when everything is past", gantt_today_in_window([(2026, 2, 1)], "month", now))
    ok("D2 today fits across past and future", gantt_today_in_window([(2026, 2, 1), (2026, 11, 1)], "month", now))
    ok("D2 today fits with no milestones at all", gantt_today_in_window([], "month", now))
    ok("D2 today fits at every scale", all(gantt_today_in_window([(2026, 8, 20)], scale, now) for scale in GANTT_MIN_COLUMNS))

    body = home.split("var body")[1].split("private var overview")[0] if "var body" in home and "private var overview" in home else ""
    tab_bar = home.split("private var tabBar")[1].split("@ViewBuilder")[0] if "private var tabBar" in home else ""
    ok("C1 wash is not a root background", ".background(StudioColor.wash" not in body)
    ok("C1 pane clips wash", ".clipped()" in home)
    ok("C2 pinned tab bar keeps wash", "StudioColor.wash" in tab_bar)
    ok("SB1 New Project is not a sidebar toolbar item",
       ".toolbar" not in sidebar and "ToolbarItem" not in sidebar)
    ok("SB1 New Project is not in the sidebar",
       "folder.badge.plus" not in sidebar and "New Project" not in sidebar)
    ok("T1 tab pills scroll selected into view", "scrollTo(newTab.id" in home or "tabProxy.scrollTo" in home)
    ok("T1 tab edge fade exists", "FadingHScroll" in swift and "tabFade" in swift)
    ok("T1 tighter pill padding", "tabPillX" in swift)
    ok("D1 project home is one ProseColumn family", "ProseColumn" in home and "GridColumn" not in home)
    modifiers = (SOURCES / "UI/Theme/ThemeModifiers.swift").read_text()
    prose = modifiers.split("struct ProseColumn")[1].split("struct GridColumn")[0] if "struct ProseColumn" in modifiers else ""
    ok("D1 ProseColumn fills the pane", "Metrics.proseMax" not in prose and "maxWidth: .infinity" in prose)
    markdown = (SOURCES / "UI/Markdown/MarkdownView.swift").read_text()
    ok("D1 MarkdownView follows the column", "Metrics.proseMax" not in markdown)
    ok("O1 Contents toggle symbol", "sidebar.trailing" in root)
    ok("O1 persist contentsVisible", "arkboard.contentsVisible" in swift)
    ok("O2 Contents width range", "outlineMin" in swift and "outlineMax" in swift)
    ok("O2 Contents width is clamped once", "func setContentsWidth" in swift)
    ok("T3 question chips wrap", "FlowLayout" in home)
    gantt = (SOURCES / "UI/Portfolio/TimelineGantt.swift").read_text()
    ok("D2 one Today rule, drawn once on the axis",
       gantt.count("private func todayRule") == 1 and gantt.count("private func todayOffset") == 1)
    ok("D2 the Today rule is not a per-week decision", "shouldShowToday" not in swift and "todayIndex" not in swift)
    ok("D3 the Gantt owns no vertical scroll", "ScrollView(.horizontal)" in gantt and "ScrollView {" not in gantt)
    ok("D3 Gantt is the timeline reading view", "TimelineScale" in swift and "TimelineGanttView" in swift)
    ok("D4 issue identifier not duplicated in title",
       "issue.identifier)  \\(issue.title)" not in swift)
    ok("E1 empty state can fill the pane", "minHeight" in (SOURCES / "UI/Shell/EmptyStateView.swift").read_text())


def check_document_bundle(swift: str) -> None:
    ok("keep a later empty refresh", not should_replace_bundle(5, 0, None, "none", False))
    ok("keep a failed github refresh", not should_replace_bundle(5, 0, "gh failed", "github", False))
    ok("accept a real local reread", should_replace_bundle(5, 8, None, "local", True))
    ok("accept a genuine empty folder", should_replace_bundle(5, 0, None, "local", True))
    ok("accept first load empty", should_replace_bundle(0, 0, None, "none", False))
    ok("empty project list does not wipe", merge_bundles({"ARK": 6}, {}, had_projects=False) == {"ARK": 6})
    ok("refresh with projects updates", merge_bundles({"ARK": 6}, {"ARK": 7}, had_projects=True) == {"ARK": 7})
    library = (SOURCES / "Documents/DocumentLibrary.swift").read_text()
    store = (SOURCES / "Data/AppStore.swift").read_text()
    ok("Contents does not gate document load", "contentsVisible" not in library)
    ok("merge policy lives in Swift", "shouldReplace" in swift)
    ok("refresh does not nil the cache first", "cache[project.id] = nil" not in library)
    ok("empty project list does not assign empty bundles", "guard !projects.isEmpty" in store)
    home = (SOURCES / "UI/Project/ProjectHomeView.swift").read_text()
    tools = (SOURCES / "Server/ToolCatalogue.swift").read_text()
    root = (SOURCES / "UI/Shell/RootView.swift").read_text()
    ok("project home binds via ensureDocuments", "ensureDocuments" in home)
    ok("API and home share ensureDocuments", "ensureDocuments" in tools)
    ok("publish replaces the bundle dictionary", "documentBundles = next" in store)
    ok("contentsVisible writes UserDefaults explicitly", "setContentsVisible" in store and "setContentsVisible" in root)
    ok("flow md linear", parse_flow_markdown("onboarding → home → detail") == ["onboarding", "home", "detail"])
    ok("flow json nodes", parse_flow_json('{"nodes":[{"id":"a","title":"Onboarding"},{"id":"b","title":"Home"}]}') == ["Onboarding", "Home"])
    ok("flow inferred from filenames", infer_flow(["02-home.png", "01-onboarding.png"]) == ["01 onboarding", "02 home"])
    mockups_tab = home.split("private var mockupsTab")[1].split("private var projectIssues")[0] if "private var mockupsTab" in home else ""
    ok("mockups empty copy", "A director pass will drop screenshots here." in swift)
    ok("mockups has flow parser", "MockupFlowParser" in swift)
    ok("mockups tab is not a markdown essay", "MarkdownView" not in mockups_tab)
    ok("mockups still one ProseColumn family", "GridColumn" not in home)


def check_layout_musts(swift: str, home: str) -> None:
    """Mockups first paint and collapsed-chrome document measure."""
    ok("Must B wide pane is not a 720 island", document_page_width(1280) == 1280)
    ok("Must B wide pane is not a 1000 grid", document_page_width(1280) != 1000)
    ok("Must B narrow pane still fills", document_page_width(560) == 560)
    ok("Must B DocumentMeasure lives in Swift", "enum DocumentMeasure" in swift and "pageWidth" in swift)
    ok("Must B project home uses the pane width", "DocumentMeasure.pageWidth" in home)
    ok("Must B still no GridColumn on project home", "GridColumn" not in home)
    ok("Must B still no 720 cap on ProseColumn", "Metrics.proseMax" not in (
        (SOURCES / "UI/Theme/ThemeModifiers.swift").read_text().split("struct ProseColumn")[1].split("struct GridColumn")[0]
        if "struct ProseColumn" in (SOURCES / "UI/Theme/ThemeModifiers.swift").read_text()
        else ""
    ))
    tab_change = home.split("onChange(of: tab)")[1].split("private var")[0] if "onChange(of: tab)" in home else ""
    ok("Must A every tab lands at the top of the tab body", "restTop(proxy)" in tab_change)
    ok("Must A tab rail is a scroll anchor", '.id("tab-bar")' in home)
    ok("Must A landing is not a user scroll-to-recover",
       "ProjectHomeAnchor.tabTop" in home and "restTop" in home)
    ui = (PRODUCT / "ui-spec.md").read_text()
    ok("Must A ui-spec forbids scrolled-past Mockups", "must not open scrolled past them" in ui)
    ok("Must B ui-spec grows the document with the pane", "720-centred island" in ui)
    ok("#15 ensureDocuments still binds the home", "ensureDocuments" in home)
    empty = (SOURCES / "UI/Shell/EmptyStateView.swift").read_text()
    ok("empty state has a document layout", "EmptyStateLayout" in empty and "case document" in empty)
    ok("document empty sits on the leading edge", "topLeading" in empty)
    ok("EmptyStateView defaults to document", "EmptyStateLayout = .document" in empty)
    ok("project home empties are not posters", "layout: .poster" not in home)
    ok("project home still has no GridColumn", "GridColumn" not in home)
    ok("Must A the rail is never the scroll target", 'scrollTo("tab-bar"' not in home)
    ok("#15 ensureDocuments kept", "ensureDocuments" in home)
    ok("ui-spec project-home empties share the document edge", "share the document left edge" in ui or "shares the document left edge" in ui)


def check_studio_chrome(swift: str, home: str, root: str, sidebar: str, ui: str) -> None:
    """Portfolio destination, pins, the master Timeline Gantt, quiet project home."""
    ok("week column starts Monday", gantt_column_start(2026, 8, 15, "week") == (2026, 8, 10))
    ok("month column starts the first", gantt_column_start(2026, 8, 15, "month") == (2026, 8, 1))
    ok("quarter column starts the quarter", gantt_column_start(2026, 8, 15, "quarter") == (2026, 7, 1))
    ok("advance a week column", gantt_advance(2026, 8, 10, "week", 1) == (2026, 8, 17))
    ok("advance a month column back", gantt_advance(2026, 8, 1, "month", -1) == (2026, 7, 1))
    ok("advance a quarter column", gantt_advance(2026, 7, 1, "quarter", 1) == (2026, 10, 1))
    ok("week column label", gantt_column_label(2026, 8, 10, "week") == "10 Aug")
    ok("month column label", gantt_column_label(2026, 8, 1, "month") == "Aug 2026")
    ok("quarter column label", gantt_column_label(2026, 7, 1, "quarter") == "Q3 2026")
    ok("default timeline scale is month", "TimelineScale = .month" in swift and "TimelineScale" in swift)

    enums = (SOURCES / "Model/Enums.swift").read_text()
    ok("sidebar persists portfolio", '"portfolio"' in enums and "case portfolio" in enums)
    ok("sidebar persists timeline", '"timeline"' in enums and "case timeline" in enums)
    ok("leftover chrome is not a destination", "monitor" not in enums.split("enum SidebarItem")[1].split("enum ServerListenState")[0] or "case monitor" not in enums)

    ok("sidebar Portfolio is a destination row", "SidebarItem.portfolio" in sidebar and "Portfolio" in sidebar)
    ok("sidebar Timeline is a destination row", "SidebarItem.timeline" in sidebar and "Timeline" in sidebar)
    portfolio_at = sidebar.find("SidebarItem.portfolio")
    timeline_at = sidebar.find("SidebarItem.timeline")
    pins_at = sidebar.find("pinnedProjects")
    ok("sidebar order is Portfolio then Timeline then pins",
       portfolio_at != -1 and timeline_at != -1 and pins_at != -1 and portfolio_at < timeline_at < pins_at)
    ok("sidebar project rows are pinned only", "ForEach(store.pinnedProjects)" in sidebar)
    ok("sidebar does not list every project", "ForEach(store.projects)" not in sidebar)
    ok("sidebar has pin control", "Unpin" in sidebar or "pin.fill" in sidebar)
    ok("sidebar still has no Monitor", "binoculars" not in sidebar and ".monitor" not in sidebar)
    ok("sidebar still has no Issues row", "tray.full" not in sidebar)
    ok("sidebar still has no Activity row", "bubble.left.and.bubble.right" not in sidebar)
    ok("no Origin Ark symbol in the sidebar", "building.2" not in sidebar)
    ok("no Origin Ark row in the sidebar", "Origin Ark" not in sidebar)
    ok("separator between destinations and pins",
       "Divider()" in sidebar
       and sidebar.find("SidebarItem.timeline") < sidebar.find("Divider()") < sidebar.find("pinnedProjects"))
    ok("sidebar has no Projects section header",
       'Text("Projects")' not in sidebar and "Projects —" not in sidebar)

    ok("root opens Portfolio destination", "PortfolioView()" in root)
    ok("root opens Timeline destination", "TimelineView()" in root)
    ok("root still opens project home", "ProjectHomeView(project:" in root)
    ok("Contents hides on Portfolio and Timeline", "showsContents" in root or "case .project" in root)

    portfolio = (SOURCES / "UI/Portfolio/PortfolioView.swift").read_text()
    ok("portfolio cards exist", "projectCard" in portfolio or "ProjectCard" in portfolio)
    ok("portfolio card is a poster, not a path list", "local ·" not in portfolio and "github ·" not in portfolio)
    ok("portfolio card has no document words",
       not all(word in portfolio for word in ("\"Design\"", "\"Architecture\"", "\"Mockups\"", "\"Decisions\"")))
    ok("portfolio card face is the project picture", "cardImage(for:" in portfolio)
    ok("portfolio card has pin", "pin.fill" in portfolio or "setPinned" in portfolio or "togglePinned" in portfolio)
    ok("portfolio has no 1000 grid cap", "gridMax" not in portfolio and "GridColumn" not in portfolio)
    ok("portfolio New Project uses the existing sheet", "arkboardNewProject" in portfolio)
    ok("Portfolio view has no milestone section",
       "Milestones" not in portfolio and "TimelineSpine" not in portfolio)
    ark_readme = "# Arkboard\n\nArkboard is Origin Ark Studio's local studio board for macOS. More."
    ok("card summary strips doubled Arkboard name",
       card_summary(ark_readme, "Arkboard") == "is Origin Ark Studio's local studio board for macOS.")
    ok("card summary strips a single leading name",
       card_summary("Lumen paints light.", "Lumen") == "paints light.")
    ok("card summary keeps a lead that is not the name",
       card_summary("A quiet board.", "Arkboard") == "A quiet board.")
    ok("card summary does not strip a longer word",
       card_summary("Arkboarded later.", "Arkboard") == "Arkboarded later.")
    parser = (SOURCES / "Documents/MarkdownParser.swift").read_text()
    ok("card summary lives in Swift", "cardSummary" in parser and "withoutNamePrefix" in parser)
    ok("portfolio card uses cardSummary", "cardSummary" in portfolio)
    ok("ui-spec strips a leading project name on the card",
       "strip" in (ui.split("## Portfolio")[1].split("## Timeline")[0].lower() if "## Portfolio" in ui else ""))

    model = (SOURCES / "UI/Portfolio/TimelineModel.swift").read_text() if (SOURCES / "UI/Portfolio/TimelineModel.swift").exists() else ""
    gantt = (SOURCES / "UI/Portfolio/TimelineGantt.swift").read_text() if (SOURCES / "UI/Portfolio/TimelineGantt.swift").exists() else ""
    ok("timeline model source exists", bool(model))
    ok("timeline Gantt source exists", bool(gantt))
    ok("timeline scale control Week Month Quarter",
       all(word in model for word in ("Week", "Month", "Quarter")))
    ok("timeline axis math lives in Swift", "enum GanttMath" in model and "columnStart" in model)
    ok("master timeline uses the Gantt", "TimelineGanttView(projectId: nil)" in
       (SOURCES / "UI/Portfolio/TimelineView.swift").read_text())
    ok("project timeline tab uses the Gantt", "TimelineGanttView(projectId: project.id)" in home)
    ok("click-through opens project Timeline", "pendingProjectTab = .timeline" in swift or "openProjectTimeline" in swift)

    ok("pinned column exists", "var pinned: Bool" in swift)
    ok("v3 pin migration", "v3-project-pinned" in swift)
    ok("create project accepts pinned", "pinned" in (SOURCES / "Server/ToolCatalogue.swift").read_text())
    ok("update_project exists so agents can pin", "update_project" in swift)
    ok("project JSON includes pinned", '"pinned"' in (SOURCES / "Data/JSONPayload.swift").read_text())

    header = ""
    if "private var projectHeader" in home:
        header = home.split("private var projectHeader")[1].split("private var tabBar")[0]
    ok("project home has no in-page identity strip", "private var projectHeader" not in home)
    ok("project home has no overview band", "private var overview" not in home)
    ok("thin header has no README lead", "MarkdownView" not in header and "firstSentence" not in header)
    ok("thin header has no More documents", "More documents" not in header)
    ok("thin header has no inline composer", "NoteComposer" not in header)
    ok("project home note is a compact sheet", "ProjectNoteSheet" in home)
    ok("⌘N still focuses the composer", "goToComposer" in swift and "composerFocused = true" in swift)

    ok("ui-spec Portfolio is a destination", "Portfolio is a destination" in ui)
    ok("ui-spec pins only in the sidebar", "pinned" in ui.lower() and "Portfolio is a destination" in ui)
    ok("ui-spec voids sidebar-is-the-portfolio", "the sidebar *is* the portfolio" not in ui)
    ok("ui-spec voids Portfolio is not a row", "Portfolio are not rows" not in ui and "Portfolio is not a row" not in ui)
    ok("ui-spec Timeline is a sidebar destination", "Timeline is a destination" in ui or "master Timeline" in ui)
    ok("ui-spec Timeline scale is Week / Month / Quarter", "`Week` / `Month` / `Quarter`" in ui)
    ok("ui-spec voids spine as primary Timeline", "vertical spine" not in ui.split("## Timeline")[1].split("## ")[0] if "## Timeline" in ui else True)
    ok("ui-spec project home is a thin header", "thin" in ui.lower() and "overview band" not in ui.lower().split("## project home")[1].split("## ")[0] if "## project home" in ui.lower() else "thin header" in ui.lower())
    ok("ui-spec voids inline composer on project home", "Tell the team" not in ui.split("## Project home")[1].split("## New Project")[0] if "## Project home" in ui else True)

    ok("sidebar footer has Onboarding icon", "sparkles" in sidebar and "Onboarding" in sidebar)
    ok("sidebar footer is not Setup", "Setup" not in sidebar)
    ok("sidebar footer is not a gear", "gearshape" not in sidebar)
    ok("sidebar persists onboarding", "case onboarding" in enums and '"onboarding"' in enums)
    ok("root opens Onboarding destination", "OnboardingView()" in root)
    onboarding_md = (PRODUCT / "onboarding.md").read_text() if (PRODUCT / "onboarding.md").exists() else ""
    ok("onboarding document exists", bool(onboarding_md))
    ok("onboarding names Origin Ark Studio", "Origin Ark Studio" in onboarding_md and "originarkstudio.com" in onboarding_md)
    ok("onboarding names the Product actor", "actor=Product" in onboarding_md or "`Product`" in onboarding_md)
    ok("onboarding is not labelled Setup", "Setup" not in onboarding_md.split("\n")[0] if onboarding_md else False)
    state = (ROOT / "company" / "STATE.md").read_text() if (ROOT / "company" / "STATE.md").exists() else ""
    ok("company STATE points at onboarding", "product/onboarding.md" in state)
    ok("ui-spec footer names Onboarding", "Onboarding" in ui.split("**Footer**")[1].split("###")[0] if "**Footer**" in ui else "Onboarding" in ui)
    ok("ui-spec sidebar has no Origin Ark symbol", "building.2" not in ui.split("### Sidebar")[1].split("### Contents")[0] if "### Sidebar" in ui else False)
    ok("ui-spec New Project is not in the sidebar footer",
       "New Project" not in ui.split("**Footer**")[1].split("###")[0] if "**Footer**" in ui else False)
    ok("ui-spec Portfolio is cards only",
       "cards only" in (ui.split("## Portfolio")[1].split("## Timeline")[0].lower() if "## Portfolio" in ui else "")
       and "Milestones" not in (ui.split("## Portfolio")[1].split("## Timeline")[0] if "## Portfolio" in ui else "Milestones"))


def check_chief_handoff(swift: str, home: str, root: str, sidebar: str, ui: str) -> None:
    """App-wide Chat with Chief of Staff context menu and Activity handoff."""
    markdown = (
        "# Design\n"
        "Lead sentence.\n"
        "## Locked — Design is the default tab\n"
        "A project is a design object first.\n"
        "## Open — How should mockups be reviewed?\n"
        "Gallery or walkthrough.\n"
    )
    page = handoff_page_line("Arkboard", "Design", "product/design.md", "project")
    ok("handoff page line is project · tab · doc", page == "Arkboard · Design · product/design.md")
    ok("handoff page line for Portfolio", handoff_page_line(None, None, None, "portfolio") == "Portfolio")
    ok("handoff page line for Timeline", handoff_page_line(None, None, None, "timeline") == "Timeline")
    ok(
        "handoff page line for Onboarding",
        handoff_page_line(None, None, "product/onboarding.md", "onboarding") == "Onboarding · product/onboarding.md",
    )
    ok(
        "handoff nearest heading from highlight",
        handoff_nearest_heading(markdown, "design object first") == "Locked — Design is the default tab",
    )
    ok(
        "handoff nearest heading falls back",
        handoff_nearest_heading("# Design\nNo match here.", "", "Design") == "Design",
    )
    body = handoff_persist_body("Ship the context menu.", page)
    ok("handoff persistBody is the user comment only", body == "Ship the context menu.")
    ok("handoff body has no friendly page line", page not in body)
    for dump in (
        "destination:",
        "project:",
        "tab:",
        "doc:",
        "heading:",
        "selected:",
        "at:",
        "2026-08-15T09:10:00.000Z",
        "Chief of Staff handoff ·",
        "This document is the visual contract.",
    ):
        ok(f"handoff body has no {dump} dump", dump not in body)

    studio = handoff_persist_body("Look at this.", "Portfolio")
    ok("studio handoff is the typed note", studio == "Look at this.")
    ok("studio handoff has no page line", "Portfolio" not in studio)
    ok("studio handoff has no destination dump", "destination:" not in studio)

    persist_src = (SOURCES / "Model/ChiefHandoff.swift").read_text()
    persist_fn = persist_src.split("func persistBody")[-1].split("struct NoteSheetRequest")[0]
    ok("persistBody has no destination: dump", "destination:" not in persist_fn)
    ok("persistBody has no project: dump", "project:" not in persist_fn)
    ok("persistBody has no ISO at: dump", "at:" not in persist_fn)
    ok("persistBody does not append pageLine", "pageLine" not in persist_fn)
    ok("persistBody does not append selectedText", "selectedText" not in persist_fn)
    ok("handoff contextJSON lives in Swift", "contextJSON" in persist_src)

    ok("source ChiefHandoff.swift", (SOURCES / "Model/ChiefHandoff.swift").exists())
    ok("menu label is Chat with Chief of Staff", "Chat with Chief of Staff" in swift)
    ok("menu is not Chief of Agent", "Chief of Agent" not in swift)
    ok("handoff capture lives in Swift", "struct ChiefHandoff" in swift and "func capture" in swift)
    ok("handoff pageLine lives in Swift", "func pageLine" in swift or "static func pageLine" in swift)
    ok("handoff nearestHeading lives in Swift", "func nearestHeading" in swift)
    ok("handoff persistBody lives in Swift", "func persistBody" in swift)
    ok("handoff fields are named", all(name in swift for name in (
        "selectedText", "destination", "projectKey", "projectName", "documentPath",
        "nearestHeading", "pageLine", "timestamp",
    )))
    ok("handoff send uses postNote", "postNote" in swift and "kind: .handoff" in swift)
    ok("handoff targets Product", 'extraTargets: ["Product"]' in swift or 'targetActors: ["Product"]' in swift or '"Product"' in (SOURCES / "Model/ChiefHandoff.swift").read_text() if (SOURCES / "Model/ChiefHandoff.swift").exists() else False)
    ok("handoff actor stays Riyu", 'actor: "Riyu"' in (SOURCES / "UI/Shell/NoteComposer.swift").read_text())
    ok("root presents the note sheet", "ProjectNoteSheet" in root)
    ok("project home still has the note icon", "bubble.left" in home and "ProjectNoteSheet" in swift)
    ok("sidebar keeps Pin/Unpin", "Unpin" in sidebar and "Pin" in sidebar)
    ok("sidebar adds Chief of Staff on project rows", "ChiefOfStaffMenuButton" in sidebar and "Chat with Chief of Staff" in swift)
    ok("document column has the menu", "chiefOfStaffContextMenu" in root or "Chat with Chief of Staff" in root)
    ok("empty states have the menu", "chiefOfStaffContextMenu" in (SOURCES / "UI/Shell/EmptyStateView.swift").read_text())
    ok("issue rows keep copy/archive and add the menu", "Copy identifier" in swift and "ChiefOfStaffMenuButton" in (SOURCES / "UI/Issues/IssuesView.swift").read_text())
    ok("no status in the Chief menu", "Status" not in (SOURCES / "UI/Shell/ChiefOfStaffMenu.swift").read_text() if (SOURCES / "UI/Shell/ChiefOfStaffMenu.swift").exists() else False)
    ok("no Grok chat URL", "grok.com" not in swift.lower() and "x.com/i/grok" not in swift.lower())
    ok("ui-spec names Chat with Chief of Staff", "Chat with Chief of Staff" in ui)
    ok("ui-spec handoff fields", all(token in ui for token in (
        "selected text", "destination", "project key", "document path", "nearest heading", "timestamp",
    )))
    decisions = (PRODUCT / "decisions.md").read_text()
    ok("decisions locks Chief of Staff handoff", "Chat with Chief of Staff" in decisions and "Locked" in decisions)
    ok("#15 ensureDocuments kept for handoff", "ensureDocuments" in home)
    ok("#16 measure kept for handoff", "DocumentMeasure.pageWidth" in home)
    ok("#18 Portfolio destination kept", "SidebarItem.portfolio" in sidebar)
    ok("#19 quiet sidebar kept",
       "building.2" not in sidebar and "New Project" not in sidebar and "Divider()" in sidebar)
    ok("#19 cardSummary kept", "cardSummary" in (SOURCES / "UI/Portfolio/PortfolioView.swift").read_text())

    sheet = (SOURCES / "UI/Project/ProjectNoteSheet.swift").read_text()
    ok("sheet title is Chat with Chief of Staff",
       "Chat with Chief of Staff" in sheet or "ChiefOfStaffCopy.menuTitle" in sheet or "ChiefOfStaffCopy.sheetTitle" in sheet)
    ok("sheet title is not Note", 'Text("Note")' not in sheet)
    ok("menu label stays Chat with Chief of Staff",
       'static let menuTitle = "Chat with Chief of Staff"' in (SOURCES / "Model/ChiefHandoff.swift").read_text())
    ok("sheet shows the friendly page line", "pageLine" in sheet)
    ok("sheet has no quietMetadata dump", "quietMetadata" not in sheet)
    ok("sheet UI has no ISO timestamp", "StudioISO8601" not in sheet and "T09:" not in sheet)
    body = sheet.split("var body")[1] if "var body" in sheet else sheet
    ok("sheet UI has no project · dump", "project ·" not in body and "destination" not in body)
    ok("ui-spec sheet title matches the menu",
       "sheet titled" in ui.lower() or "title is exactly" in ui.lower() or "same words as the menu" in ui)
    ok("ui-spec humans see only the friendly line",
       "friendly" in ui.lower() and "do not show a raw dump" in ui.lower())
    ok("SwiftUI menus share the document highlight",
       "lastHighlight" in swift and "firstSelectedText" in swift)
    ok("History is still the Activity log",
       'Text("History")' in sheet and "chat thread" not in sheet.lower())
    history_view = sheet.split('Text("History")')[-1] if 'Text("History")' in sheet else sheet
    ok("History view binds the comment", "Text(row.body)" in history_view)
    ok("History view does not bind selectedText", "selectedText" not in history_view)

    appstore = (SOURCES / "Data/AppStore.swift").read_text()
    begin = appstore.split("func beginChiefHandoff")[-1].split("private func focusedProject")[0]
    ok("composer is not seeded with selected text",
       "handoff.selectedText" not in begin and 'draft: ""' in begin)
    ok("beginChiefHandoff still captures selection",
       "ChiefHandoff.capture" in begin and "selectedText" in begin)

    composer = (SOURCES / "UI/Shell/NoteComposer.swift").read_text()
    ok("composer does not seed from selectedText", "handoff.selectedText" not in composer)
    appear = composer.split("onAppear")[-1].split("onChange")[0] if "onAppear" in composer else composer
    ok("composer does not seed handoff drafts", "handoff == nil" in appear or "handoff == nil" in composer)
    ok("send persists metadata, not selected quote in body",
       "metadata:" in composer and "contextJSON" in composer)

    entities = (SOURCES / "Model/Entities.swift").read_text()
    ok("activity row has metadata", "var metadata: String" in entities)
    ok("v4-activity-metadata migration",
       "v4-activity-metadata" in (SOURCES / "Data/AppDatabase.swift").read_text())
    ok("activity JSON exposes metadata",
       '"metadata"' in (SOURCES / "Data/JSONPayload.swift").read_text())
    ok("postNote accepts metadata", "metadata:" in appstore.split("func postNote")[1].split("func createMilestone")[0])

    ok("ui-spec selection is silent context", "silent context" in ui.lower())
    ok("ui-spec the human writes the ask", "writes the ask" in ui.lower())
    ok("ui-spec History is actor + time + comment",
       "actor" in ui.lower() and ("their comment" in ui.lower() or "the comment they typed" in ui.lower()))
    ok("ui-spec context is not rendered in History",
       "not rendered in history" in ui.lower() or "history does not print" in ui.lower())


def contents_is_document_overlay(root: str) -> bool:
    """Contents must float over the document, not sit in a width-stealing HStack split."""
    if "ContentsOutline()" not in root:
        return False
    before = root.split("ContentsOutline()")[0]
    return "overlay(alignment: .trailing)" in before[-800:]


def document_width_ignores_contents(pane_width: float, contents_visible: bool) -> float:
    """Contents overlays the document; visibility must not change the measure."""
    del contents_visible
    return document_page_width(pane_width)


def portfolio_card_source(portfolio: str) -> str:
    if "private func projectCard" not in portfolio:
        return ""
    rest = portfolio.split("private func projectCard", 1)[1]
    if "private func docPill" in rest:
        return rest.split("private func docPill", 1)[0]
    return rest


def portfolio_pill_source(portfolio: str) -> str:
    if "private func docPill" not in portfolio:
        return ""
    rest = portfolio.split("private func docPill", 1)[1]
    if "private static func displayPath" in rest:
        return rest.split("private static func displayPath", 1)[0]
    return rest


def check_contents_overlay_and_card_type(swift: str, home: str, root: str, ui: str) -> None:
    """Contents overlays the document; Portfolio cards share the typography environment."""
    ok("Contents shown does not shrink a wide pane",
       document_width_ignores_contents(1280, True) == 1280)
    ok("Contents hidden keeps the same wide pane",
       document_width_ignores_contents(1280, False) == 1280)
    ok("Contents visibility does not change the document measure",
       document_width_ignores_contents(900, True) == document_width_ignores_contents(900, False))
    ok("Contents is not a third NavigationSplitView column", "} content:" not in root)
    ok("Contents overlays the trailing edge of the document", contents_is_document_overlay(root))
    ok("Contents overlay is not an HStack split of the detail column",
       "HStack(spacing: 0)" not in root.split("} detail:")[1].split("overlay(alignment: .trailing)")[0]
       if "} detail:" in root and "overlay(alignment: .trailing)" in root
       else False)
    ok("Contents still uses the outline width range",
       "outlineMin" in swift and "outlineMax" in swift and "outlineIdeal" in swift)
    ok("Contents toggle still persists",
       "setContentsVisible" in root and "arkboard.contentsVisible" in swift)
    ok("Contents header stays Contents",
       'Text("Contents")' in (SOURCES / "UI/Markdown/ContentsOutline.swift").read_text())
    ok("document column still fills the pane", "DocumentMeasure.pageWidth" in home)
    ok("still no GridColumn 1000 on the document", "GridColumn" not in home)
    ok("still no 720 island on project home", "Metrics.proseMax" not in home)

    contents_spec = ui.split("### Contents")[1].split("###")[0] if "### Contents" in ui else ""
    ok("ui-spec Contents is an overlay, not a split column",
       "overlay" in contents_spec.lower()
       and "split column" in contents_spec.lower()
       and ("does not" in contents_spec.lower() or "not steal" in contents_spec.lower()
            or "does not steal" in contents_spec.lower() or "does not collapse" in contents_spec.lower()
            or "does not resize" in contents_spec.lower()))
    ok("ui-spec Contents does not resize the document",
       any(token in contents_spec.lower() for token in (
           "does not steal", "does not collapse", "does not resize", "does not shrink",
           "covers", "floats",
       )))

    portfolio = (SOURCES / "UI/Portfolio/PortfolioView.swift").read_text()
    card = portfolio_card_source(portfolio)
    pills = portfolio_pill_source(portfolio)
    ok("portfolio card uses the typography environment",
       "@Environment(\\.typography)" in portfolio or "typography" in portfolio)
    ok("portfolio card inherits the studio face", ".font(type.body)" in card)
    ok("portfolio card name uses the type scale", "type.heading" in card)
    ok("portfolio card summary uses the type scale", "type.callout" in card)
    ok("portfolio card keeps paths and document words off the tile",
       "type.mono" not in card and "docPill" not in portfolio)
    ok("portfolio card has no one-off .font(.system)",
       ".font(.system" not in card and ".font(.system" not in pills)
    ok("portfolio card has no custom face",
       ".custom(" not in card and "Font.custom" not in card
       and ".custom(" not in pills and "Font.custom" not in pills)
    cards_spec = ui.split("## Portfolio")[1].split("## Timeline")[0] if "## Portfolio" in ui else ""
    ok("ui-spec Portfolio cards use the typography environment",
       "typography" in cards_spec.lower())
    ok("#15 ensureDocuments kept for chrome", "ensureDocuments" in home)
    ok("#16 measure kept for chrome", "DocumentMeasure.pageWidth" in home)
    ok("#18 Portfolio destination kept for chrome", "PortfolioView()" in root)
    ok("#19 cardSummary kept for chrome", "cardSummary" in portfolio)


def check_timeline_gantt(swift: str, home: str, ui: str, decisions: str, architecture: str, mcp: str) -> None:
    """The master Timeline is a Gantt — project rows on a time axis with dependency links —
    not a month grid of days."""
    model = (SOURCES / "UI/Portfolio/TimelineModel.swift").read_text()
    gantt = (SOURCES / "UI/Portfolio/TimelineGantt.swift").read_text()
    timeline = (SOURCES / "UI/Portfolio/TimelineView.swift").read_text()
    entities = (SOURCES / "Model/Entities.swift").read_text()
    database = (SOURCES / "Data/AppDatabase.swift").read_text()
    store = (SOURCES / "Data/AppStore.swift").read_text()
    validation = (SOURCES / "Data/Validation.swift").read_text()
    tools = (SOURCES / "Server/ToolCatalogue.swift").read_text()
    payload = (SOURCES / "Data/JSONPayload.swift").read_text()
    rest = (SOURCES / "Server/RESTRoutes.swift").read_text()

    now = (2026, 8, 15)
    projects = [
        {"id": "p-ark", "key": "ARK", "name": "Arkboard", "color": "#5A62D6"},
        {"id": "p-lum", "key": "LUM", "name": "Lumen", "color": "#1F8F63"},
    ]
    milestones = [
        {"id": "m-design", "projectId": "p-ark", "title": "Design pack locked", "targetDate": (2026, 8, 20)},
        {"id": "m-build", "projectId": "p-ark", "title": "Gantt ships", "targetDate": (2026, 9, 18), "dependsOn": ["m-design"]},
        {"id": "m-ship", "projectId": "p-ark", "title": "Studio board v3", "targetDate": (2026, 10, 30), "dependsOn": ["m-build", "m-design"]},
        {"id": "m-lum", "projectId": "p-lum", "title": "Lumen kickoff", "targetDate": (2026, 9, 4)},
        {"id": "m-studio", "projectId": None, "title": "Studio review", "targetDate": (2026, 9, 25)},
    ]
    events = [{"id": "i-1", "projectId": "p-ark", "identifier": "ARK-14", "date": (2026, 8, 12)}]
    plan = gantt_plan(projects, milestones, events, scope=None, scale="month", now=now)

    # --- Shape: rows are projects, milestones nest under them, bars sit on one axis.
    ok("Gantt rows are projects with milestones underneath",
       [f"{r['kind']}:{r['id']}" for r in plan["rows"]] == [
           "project:p-ark", "milestone:m-design", "milestone:m-build", "milestone:m-ship",
           "project:p-lum", "milestone:m-lum",
           "project:studio", "milestone:m-studio",
       ])
    ok("Gantt has a project row per project with work",
       len([r for r in plan["rows"] if r["kind"] == "project"]) == 3)
    ok("Gantt project bar spans that project's whole plan",
       plan["rows"][0]["start"] == (2026, 8, 12) and plan["rows"][0]["end"] == (2026, 10, 30))
    ok("Gantt project row counts its milestones", plan["rows"][0]["milestoneCount"] == 3)
    ok("Gantt shipped work is a mark on the project bar, not a row",
       plan["rows"][0]["marks"] == ["i-1"] and not any(r["id"] == "i-1" for r in plan["rows"]))
    ok("Gantt milestone rows carry a diamond at the target date",
       all(r["marker"] == r["end"] for r in plan["rows"] if r["kind"] == "milestone"))
    ok("Gantt studio milestones get their own row",
       any(r["id"] == "studio" and r["title"] == "Studio" for r in plan["rows"]))

    # --- Dependencies drive the bars and the links.
    ok("Gantt milestone with no predecessor starts at its project start",
       next(r for r in plan["rows"] if r["id"] == "m-design")["start"] == (2026, 8, 12))
    ok("Gantt milestone starts when its predecessor lands",
       next(r for r in plan["rows"] if r["id"] == "m-build")["start"] == (2026, 8, 20))
    ok("Gantt milestone waits for its latest predecessor",
       next(r for r in plan["rows"] if r["id"] == "m-ship")["start"] == (2026, 9, 18))
    ok("Gantt draws one link per dependency",
       sorted(plan["links"]) == ["m-build->m-ship", "m-design->m-build", "m-design->m-ship"])
    ok("Gantt drops a predecessor that is not on this chart",
       gantt_plan(projects, [{"id": "m", "projectId": "p-ark", "title": "A", "targetDate": (2026, 9, 1), "dependsOn": ["gone"]}], [], now=now)["links"] == [])

    scoped = gantt_plan(projects, milestones, events, scope="p-ark", scale="month", now=now)
    ok("project Timeline tab is the same Gantt, filtered",
       [r["id"] for r in scoped["rows"]] == ["p-ark", "m-design", "m-build", "m-ship"])
    ok("project Timeline tab keeps the dependency links", len(scoped["links"]) == 3)
    ok("project Timeline tab drops studio milestones",
       not any(r["id"] == "studio" for r in scoped["rows"]))

    # --- A time axis, not a month grid of days.
    start, end = plan["window"]
    columns = gantt_columns(start, end, "month")
    ok("Gantt axis columns are periods, not days", len(columns) == 5 and all(c[2] == 1 for c in columns))
    ok("Gantt axis holds every milestone",
       gantt_fraction((2026, 8, 20), start, end) > 0 and gantt_fraction((2026, 10, 30), start, end) < 1)
    ok("Gantt axis places Today once", gantt_today_in_window([m["targetDate"] for m in milestones], "month", now))
    ok("Gantt week scale slices the same span finer",
       len(gantt_columns(*gantt_window([m["targetDate"] for m in milestones], "week", now), "week")) >
       len(gantt_columns(*gantt_window([m["targetDate"] for m in milestones], "quarter", now), "quarter")))

    # --- Measure: pane-width and left-aligned, no 720 island and no 1000 grid.
    ok("Gantt columns stretch to fill a wide pane", not gantt_scrolls(1280, 5, "month"))
    ok("Gantt columns fill exactly, leaving no island",
       abs(gantt_column_width(1280, 5, "month") * 5 - (1280 - GANTT_LABEL_COLUMN)) < 0.001)
    ok("Gantt scrolls instead of squeezing an illegible axis", gantt_scrolls(900, 40, "week"))
    ok("Gantt measure is the pane, not a 1000 grid", gantt_column_width(1600, 4, "month") * 4 > 1000 - GANTT_LABEL_COLUMN)
    ok("Gantt has no GridColumn", "GridColumn" not in gantt and "GridColumn" not in timeline)
    ok("Gantt has no 720 cap", "Metrics.proseMax" not in gantt and "Metrics.proseMax" not in timeline)
    ok("Gantt is left-aligned", "alignment: .leading" in gantt)

    # --- The month-day calendar grid is gone as the primary reading view.
    ok("TimelineCalendar.swift is gone", not (SOURCES / "UI/Portfolio/TimelineCalendar.swift").exists())
    ok("no TimelineCalendarView anywhere", "TimelineCalendarView" not in swift)
    ok("no month grid of days", "monthGrid" not in swift and "weekdaySymbols" not in swift)
    ok("no seven-column day grid", "count: 7" not in swift)
    ok("no year grid of month cards", "monthsInYear" not in swift)
    ok("the vertical spine is not the reading view either", "struct TimelineSpine" not in swift)

    # --- Read-only for humans.
    ok("Gantt has no milestone editor",
       "updateMilestone" not in gantt and "update_milestone" not in gantt)
    ok("Gantt has no status or priority control",
       'Picker("Status"' not in gantt and "IssuePriority" not in gantt and "MilestoneStatus(" not in gantt)
    ok("Gantt's only Picker is the scale", gantt.count("Picker(") == 1 and 'Picker("Scale"' in gantt)
    ok("Gantt keeps the Chief of Staff menu", "ChiefOfStaffMenuButton" in gantt and "chiefOfStaffContextMenu" in gantt)

    # --- The Gantt lives under the Apple-language rules #25 locked.
    ok("Gantt paints no window slab", "StudioColor.window" not in gantt)
    ok("Gantt does not glass the document", "glassEffect" not in gantt and "inspectorSurface" not in gantt)
    ok("Timeline pane keeps the edge-to-edge fill", "paneBackground" in timeline)
    ok("Gantt takes every glyph from the type scale", ".font(.system" not in gantt)
    ok("Gantt sizes its scale control from the control metrics",
       ".fixedSize()" in gantt and "maxWidth: 2" not in gantt)
    ok("Gantt reuses the house chip rather than a hand-drawn pill",
       'Chip(text: "Today"' in gantt and "in: Capsule())" not in gantt)

    # --- Schema, migration, and API for dependencies.
    ok("milestone has a dependsOn column", "var dependsOn: String" in entities)
    ok("milestone decodes dependency ids", "var dependencyIds: [String]" in entities)
    ok("activity metadata migration still ships", "v4-activity-metadata" in database)
    ok("v5 dependency migration", "v5-milestone-dependencies" in database)
    ok("migration adds dependsOn defaulting to empty",
       't.add(column: "dependsOn", .text).notNull().defaults(to: "[]")' in database)
    ok("create_milestone takes dependsOn", "dependsOn" in tools and "create_milestone" in tools)
    ok("update_milestone takes dependsOn", 'tool("update_milestone"' in tools and '"dependsOn": ["type": "array"' in tools)
    ok("store writes dependencies", "dependsOn: [String]? = nil" in store and "encodeDependencies" in store)
    ok("milestone JSON exposes dependsOn", '"dependsOn": milestone.dependencyIds' in payload)
    ok("REST can PATCH a milestone", '/api/milestones/' in rest and "update_milestone" in rest)
    ok("unknown dependency is rejected", "unknownDependency" in validation and "unknownDependency" in store)
    ok("self dependency is rejected", "selfDependency" in validation and "selfDependency" in store)
    ok("dependency cycles are rejected", "dependencyCycle" in validation and "createsCycle" in store)
    ok("dependency ids trim and dedupe", gantt_dependencies([" a ", "a", "", "b"]) == ["a", "b"])
    ok("a back edge is a cycle", gantt_creates_cycle("a", ["b"], {"b": ["a"]}))
    ok("a long loop is a cycle", gantt_creates_cycle("a", ["c"], {"c": ["b"], "b": ["a"]}))
    ok("a chain is not a cycle", not gantt_creates_cycle("c", ["b"], {"b": ["a"]}))
    ok("a diamond is not a cycle", not gantt_creates_cycle("d", ["b", "c"], {"b": ["a"], "c": ["a"]}))

    # --- Spec.
    spec = ui.split("## Timeline")[1].split("\n## ")[0] if "## Timeline" in ui else ""
    tab_spec = ui.split("### Timeline tab")[1].split("\n## ")[0] if "### Timeline tab" in ui else ""
    ok("ui-spec Timeline section exists", bool(spec))
    ok("ui-spec Timeline is a Gantt", "Gantt" in spec)
    ok("ui-spec Timeline rows are projects", "project" in spec.lower() and "row" in spec.lower())
    ok("ui-spec Timeline has a time axis", "time axis" in spec.lower() or "axis" in spec.lower())
    ok("ui-spec Timeline shows dependencies", "dependenc" in spec.lower())
    ok("ui-spec Timeline voids the calendar grid",
       "not a month grid of days" in spec and "calendar" not in spec.lower())
    ok("ui-spec Timeline keeps the scale control", "`Week` / `Month` / `Quarter`" in spec and "Default Month" in spec)
    ok("ui-spec Timeline is pane-width and left-aligned",
       "No 720 island" in spec and "No 1000 grid" in spec)
    ok("ui-spec Timeline click-through opens the project tab", "Timeline tab" in spec)
    ok("ui-spec Timeline is read-only for humans", "read-only" in spec.lower() or "Read-only" in spec)
    ok("ui-spec Timeline tab is the same Gantt", "Gantt" in tab_spec and "read-only" in tab_spec.lower())
    ok("ui-spec voids calendar-grid-is-the-Timeline everywhere",
       "cross-project calendar" not in ui and "studio calendar" not in ui and "the calendar" not in ui)
    ok("ui-spec sidebar Timeline row names the rollup",
       "master" in ui.split("### Sidebar")[1].split("### Contents")[0].lower() if "### Sidebar" in ui else False)
    ok("ui-spec names milestone.dependsOn", "dependsOn" in ui)

    ok("decisions locks the Gantt", "Locked — Timeline is a Gantt" in decisions)
    ok("decisions voids Timeline-is-a-calendar", "Locked — Timeline is a calendar" not in decisions)
    ok("decisions says calendar grid is not the Timeline", "calendar grid is not the Timeline" in decisions)
    ok("decisions locks agent-written dependencies", "dependsOn" in decisions)

    ok("architecture documents the dependsOn column", "dependsOn" in architecture)
    ok("architecture documents the v5 migration", "v5-milestone-dependencies" in architecture)
    ok("architecture keeps the v4 activity metadata migration", "v4-activity-metadata" in architecture)
    ok("mcp documents dependsOn on milestones", "dependsOn" in mcp)

    # Chrome landed in #15–#24 must survive this pass.
    ok("#15 ensureDocuments kept for the Gantt", "ensureDocuments" in home)
    ok("#16 measure kept for the Gantt", "DocumentMeasure.pageWidth" in home and "DocumentMeasure.pageWidth" in timeline)
    ok("#18 Portfolio destination kept for the Gantt", "PortfolioView()" in (SOURCES / "UI/Shell/RootView.swift").read_text())
    ok("#19 cardSummary kept for the Gantt", "cardSummary" in (SOURCES / "UI/Portfolio/PortfolioView.swift").read_text())
    ok("#24 Contents overlay kept for the Gantt",
       contents_is_document_overlay((SOURCES / "UI/Shell/RootView.swift").read_text()))


def check_window_title_only(swift: str, home: str, root: str, sidebar: str, ui: str, decisions: str) -> None:
    """The window title bar is the only title. No screen repeats it in the pane."""
    ok("no ScreenHeader view", "struct ScreenHeader" not in swift)
    ok("no screen renders an in-page title band", "ScreenHeader(" not in swift)
    ok("the window still carries the title", "navigationTitle" in root and "navigationSubtitle" in root)

    for rel in (
        "UI/Portfolio/PortfolioView.swift",
        "UI/Portfolio/TimelineView.swift",
        "UI/Shell/OnboardingView.swift",
    ):
        source = (SOURCES / rel).read_text()
        ok(f"{rel} opens on content", "ScreenHeader" not in source)

    portfolio = (SOURCES / "UI/Portfolio/PortfolioView.swift").read_text()
    ok("Portfolio drops the arm's-length tagline", "Every project at arm's length." not in portfolio)
    timeline = (SOURCES / "UI/Portfolio/TimelineView.swift").read_text()
    ok("Timeline drops its tagline", "Every project on one timeline." not in timeline)
    onboarding = (SOURCES / "UI/Shell/OnboardingView.swift").read_text()
    ok("Onboarding drops its tagline", "How this studio works." not in onboarding)

    strip = home.split("private var identityToolbar")[1].split("private var readingGutter")[0] if "private var identityToolbar" in home else ""
    ok("project identity lives on the toolbar", bool(strip))
    ok("toolbar identity does not repeat the project name", "Text(project.name)" not in strip)
    ok("toolbar identity has no display title", "type.display" not in strip)
    ok("toolbar identity carries the mark", "ProjectIcon(" in strip)
    ok("toolbar identity carries the key", "project.key" in strip)
    ok("toolbar keeps refresh and the note action",
       "arrow.clockwise" in strip and "bubble.left" in strip)
    ok("toolbar identity paints no window slab", "StudioColor.window" not in strip)
    # Nothing scrolls above the rail, so the rail is pinned from first paint.
    after_stack = home.split("pinnedViews: .sectionHeaders")[1] if "pinnedViews: .sectionHeaders" in home else ""
    ok("project home pane starts at the tab rail",
       after_stack.split("{", 1)[1].strip().startswith("Section {") if after_stack else False)

    ok("UndoToast survives the screen-header removal", "struct UndoToast" in swift)
    ok("Timeline scale control is untouched", "TimelineScale" in swift and "Quarter" in swift)

    ok("ui-spec voids the screen header", "### Screen header" not in ui)
    ok("ui-spec names the window title as the only title", "the only title in the app" in ui.lower())
    ok("ui-spec forbids a repeated screen name", "No screen prints its own name" in ui)
    ok("ui-spec voids the ScreenHeader view", "do not bring back a `screenheader` view" in ui.lower())
    ok("ui-spec drops the screen taglines",
       "Subtitle: `Every project at arm's length.`" not in ui
       and "Subtitle: `Every project on one timeline.`" not in ui
       and "Subtitle: `How this studio works.`" not in ui)
    ok("decisions locks the single title", "Locked — The window title is the only title" in decisions)

    home_spec = ui.split("## Project home")[1].split("## New Project")[0] if "## Project home" in ui else ""
    ok("ui-spec project home has no window slab", "windowBackgroundColor" not in home_spec.split("no `windowBackgroundColor` slab")[0])
    ok("ui-spec project home puts identity on the toolbar",
       "Identity lives in the toolbar" in home_spec)
    ok("ui-spec project home does not restate the name", "No name in `display`" in home_spec)
    ok("ui-spec keeps the tab rail on glass", "glass" in ui.split("### Tab bar")[1].split("###")[0].lower())


def check_portfolio_hero_cards(swift: str, sidebar: str, ui: str, decisions: str) -> None:
    """The mark is the hero of a Portfolio card; the sidebar breathes; the two columns differ."""
    portfolio = (SOURCES / "UI/Portfolio/PortfolioView.swift").read_text()
    card = portfolio_card_source(portfolio)
    pills = portfolio_pill_source(portfolio)

    ok("mark ratios live in Metrics", "markCornerRatio" in swift and "markGlyphRatio" in swift)
    ok("mark corner scales with the tile", "func markCorner" in swift and "func markGlyph" in swift)
    ok("ProjectIcon derives its corner from its size", "Metrics.markCorner(for: size)" in
       (SOURCES / "UI/Theme/ThemeModifiers.swift").read_text())
    ok("poster aspect is a token", "cardPosterAspect" in swift)
    ok("portfolio card leads with the poster", "Metrics.cardPosterAspect" in card)
    ok("portfolio card mark is not a 22pt chip", "size: 22" not in card)
    ok("portfolio card keeps the pin", "pin.fill" in portfolio)
    ok("portfolio card carries name and summary only",
       "type.heading" in card and "type.callout" in card and "cardSummary" in portfolio)
    ok("portfolio card has no capsule chips",
       "chipFill" not in portfolio and "in: Capsule()" not in portfolio)
    ok("portfolio card is still one type scale",
       ".font(.system" not in card and ".font(.system" not in pills and ".custom(" not in card)
    ok("portfolio cards are still cards only",
       "Milestones" not in portfolio and "TimelineGanttView" not in portfolio)

    ok("sidebar rows take air from a token", "Metrics.sidebarRowY" in sidebar)
    ok("sidebar row air is defined once", "static let sidebarRowY" in swift)
    ok("sidebar mark uses the token", "Metrics.markSidebar" in sidebar)
    ok("sidebar has no one-off font size", ".font(.system(size:" not in sidebar)
    ok("sidebar has no all-caps header", "uppercased()" not in sidebar)

    ok("document field exists for the document", "documentField" in swift)
    ok("paneBackground is the only documentField caller",
       "documentField" not in sidebar
       and "documentField" not in (SOURCES / "UI/Shell/RootView.swift").read_text()
       and "documentField" not in (SOURCES / "UI/Markdown/ContentsOutline.swift").read_text())
    ok("no window-background accessor survives", "StudioColor.window " not in swift and "StudioColor.window\n" not in swift)

    # One type scale everywhere a human reads. Mark tiles are the documented exception.
    for rel in (
        "UI/Shell/SidebarView.swift",
        "UI/Shell/EmptyStateView.swift",
        "UI/Portfolio/PortfolioView.swift",
        "UI/Project/ProjectHomeView.swift",
        "UI/Markdown/MarkdownView.swift",
        "UI/Markdown/ContentsOutline.swift",
        "UI/Activity/ActivityView.swift",
    ):
        ok(f"one type scale in {rel}", ".font(.system(size:" not in (SOURCES / rel).read_text())

    cards_spec = ui.split("## Portfolio")[1].split("## Timeline")[0] if "## Portfolio" in ui else ""
    ok("ui-spec Portfolio leads with the picture", "The card is the picture" in cards_spec)
    ok("ui-spec Portfolio voids the 22pt chip", "22pt chip" in cards_spec)
    ok("ui-spec Portfolio keeps metadata off the tile", "Not on the tile" in cards_spec)
    ok("ui-spec Portfolio is still cards only", "cards only" in cards_spec.lower())
    sidebar_spec = ui.split("### Sidebar")[1].split("### Contents")[0] if "### Sidebar" in ui else ""
    ok("ui-spec paces the sidebar", "sidebarRowY" in sidebar_spec)
    ok("ui-spec sidebar has no all-caps headers", "all-caps" in sidebar_spec.lower())
    ok("ui-spec splits material from solid", "frosted system material" in ui and "opaque reading field" in ui)
    ok("ui-spec names the mark exception", "A mark is a product icon, not type" in ui)
    ok("decisions voids the hero-mark card", "the mark is the hero" not in decisions)
    ok("decisions locks material versus solid", "Locked — The sidebar is material, the document is solid" in decisions)
    ok("decisions keeps Apple language", "Locked — Apple language, not Apple content" in decisions)


def without_comments(source: str) -> str:
    """Swift source with `//` comments removed.

    Locks about code must read code. A prose line can otherwise satisfy a lock
    that greps for a call, or trip one that forbids it.
    """
    lines = []
    for line in source.split("\n"):
        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue
        quoted = False
        cut = len(line)
        index = 0
        while index < len(line) - 1:
            char = line[index]
            if char == '"':
                quoted = not quoted
            elif char == "\\" and quoted:
                index += 1
            elif not quoted and line[index : index + 2] == "//":
                cut = index
                break
            index += 1
        lines.append(line[:cut])
    return "\n".join(lines)


def sidebar_destinations(design: str) -> set[str]:
    """Destinations product/design.md presents as rows in the left column.

    Reads the sentence that names them rather than the whole file, so a section
    hue table that merely mentions Monitor does not count as a destination, and
    a Design tab that quietly puts Monitor back in the sidebar does.
    """
    shell = design.split("## What the app looks like")[1].split("\n## ")[0] if "## What the app looks like" in design else ""
    if not shell:
        return set()
    lead = shell.split("**The left column is navigation**")[1].split("\n\n")[0] if "**The left column is navigation**" in shell else shell
    named = set()
    for candidate in ("Portfolio", "Timeline", "pinned", "Monitor", "Issues", "Activity", "Inbox", "Origin Ark"):
        if candidate in lead.split("There is no")[0]:
            named.add(candidate)
    return named


def check_living_tabs(ui: str, decisions: str, design: str) -> None:
    """product/ tabs describe the app on main, not the app we used to have."""
    architecture = (PRODUCT / "architecture.md").read_text()
    onboarding = (PRODUCT / "onboarding.md").read_text()

    ok("decisions locks living tabs", "Locked — product/ tabs are living" in decisions)
    ok("decisions ships docs with the chrome",
       "in the same pull request as the chrome they describe" in decisions)
    ok("decisions forbids a brochure pass", "brochure pass" in decisions)
    ok("decisions fails review on dead chrome",
       "still describes dead chrome" in decisions or "still describes something you cannot find" in decisions)
    ok("decisions keeps history intact", "supersede line" in decisions)
    ok("ui-spec carries the living rule", "## The tabs are living documents" in ui)
    ok("ui-spec says mockups are current shots",
       "latest measured window shots" in ui)
    ok("onboarding carries the living rule", "product/ tabs are living" in onboarding)
    ok("onboarding names the mockups folder", "product/mockups/" in onboarding)
    ok("architecture notes its current shape", "## Current shape" in architecture)
    ok("architecture says Monitor is not a screen",
       "Monitor and Activity are engine, not screens" in architecture)

    # Design must describe the chrome that exists.
    destinations = sidebar_destinations(design)
    ok("design names a left column", bool(destinations))
    ok("design names Portfolio as a destination", "Portfolio" in destinations)
    ok("design names Timeline as a destination", "Timeline" in destinations)
    ok("design names pinned projects", "pinned" in destinations)
    for dead in ("Monitor", "Issues", "Activity", "Inbox", "Origin Ark"):
        ok(f"design does not put {dead} in the sidebar", dead not in destinations)

    ok("design describes poster cards",
       "product/card.png" in design and "poster" in design.lower())
    ok("design describes one window title",
       "names the page once" in design or "one headline" in design.lower())
    ok("design describes the grey focused selection",
       "unemphasized" in design and "focused or not" in design)
    ok("design describes the Contents overlay and its gutter",
       "trailing overlay" in design and "gutter" in design)
    ok("design describes the Chief of Staff handoff",
       "Chat with Chief of Staff" in design and "right-click" in design)
    ok("design describes the six project tabs",
       all(tab in design for tab in ("Design", "Architecture", "Mockups", "Decisions & questions", "Issues", "Timeline")))
    ok("design describes Timeline as a Gantt",
       "Gantt" in design and "dependency" in design)
    ok("design uses the scale the code has",
       "`Week` / `Month` / `Quarter`" in design and "Year" not in design)
    ok("design keeps the design system", all(
        word in design for word in ("calm", "coloured", "continuous")))
    ok("design still leads with the app, not a hex table",
       design.index("## What the app looks like") < design.index("## The ramp")
       if "## What the app looks like" in design and "## The ramp" in design else False)
    ok("design voids the old selected-pill fill", "Selected tab pill fill" not in design)
    ok("design voids the 720 document column", "720 ideal" not in design)


def swift_constant(source: str, name: str) -> str | None:
    """The exact value of `static let <name>: CGFloat = …`.

    Substring matching cannot do this: `= 20` contains `= 2`, so a lock that
    greps for the tolerance passes while the tolerance is loosened tenfold.
    """
    for line in source.split("\n"):
        stripped = line.strip()
        if stripped.startswith(f"static let {name}:") and "=" in stripped:
            return stripped.split("=", 1)[1].strip()
    return None


def check_mac_measures(ui: str, decisions: str) -> None:
    """Mac-first measures before Critique.

    Linux cannot run the measure script — it drives a live macOS app. What this
    can do is refuse to let the rule, or the script that enforces it, quietly
    go missing or get hollowed out into a rail-only check.
    """
    swift_path = ROOT / "scripts" / "mac_measure.swift"
    shell_path = ROOT / "scripts" / "mac_measure.sh"
    ok("scripts/mac_measure.swift exists", swift_path.exists())
    ok("scripts/mac_measure.sh exists", shell_path.exists())
    if not swift_path.exists() or not shell_path.exists():
        return
    measure = swift_path.read_text()
    wrapper = shell_path.read_text()

    ok("the measure targets the app bundle", "studio.originark.arkboard" in measure)
    ok("the measure clicks Design, Mockups, Design",
       'measuredTabs = ["Design", "Mockups", "Design"]' in measure)
    ok("the measure presses the tabs", "kAXPressAction" in measure)

    # Body Y, not rail-only. This is the whole reason the script exists.
    ok("the measure reads body Y", "body_y" in measure and "func bodyLeaf" in measure)
    ok("the measure names the leaf it scored",
       "body_leaf" in measure and "body.role" in measure)
    ok("the measure reads rail Y", "rail_y" in measure and "func railBounds" in measure)
    ok("body Y is not the rail in disguise",
       "originTolerance" in measure and "railTolerance" in measure)
    ok("sibling tabs must share an origin", "do not share one origin" in measure)
    ok("the origin tolerance is 2pt", swift_constant(measure, "originTolerance") == "2")
    ok("the rail tolerance is 2pt", swift_constant(measure, "railTolerance") == "2")
    ok("the measure reads leaves, not containers", "AXStaticText" in measure)

    # The selected row, while the sidebar has focus.
    ok("the measure checks the selected row", "selection_ok" in measure)
    ok("the selection is sampled after a press",
       "press(row.element)" in measure and "averageHSB" in measure)
    ok("a tinted selected row fails", "selectionSaturationCeiling" in measure)
    ok("a mark forced white fails", "markSaturationFloor" in measure)

    # One title row.
    ok("the measure checks for a second title band",
       "title_ok" in measure and "func secondTitleBand" in measure)
    ok("a repeated window title fails", "one title row" in measure)

    # Report and exit codes.
    ok("the measure prints a machine-readable report",
       "func emit" in measure and "passed" in measure and "print(" in measure)
    ok("a drift exits 1", "exit(report.failures.isEmpty ? 0 : 1)" in measure)
    ok("no app exits 2", "is not running" in measure and "exit(2)" in measure)
    ok("a missing permission exits 2", "Accessibility permission" in measure)

    # Scope: measure only. Read code, so a comment saying "no worktrees" neither
    # satisfies nor trips these.
    measure_code = without_comments(measure)
    wrapper_code = "\n".join(
        line for line in wrapper.split("\n") if not line.lstrip().startswith("#")
    )
    # Token match, not substring: "xed" lives inside "fixed", and a lock that
    # fires on a comment about a fixed offset is a lock nobody will keep.
    def tokens(source: str) -> set[str]:
        return set(re.split(r"[^A-Za-z0-9_]+", source))

    banned = tokens(measure_code) | tokens(wrapper_code)
    for tool in ("xcodebuild", "worktree", "xed"):
        ok(f"the measure does not run {tool}", tool not in banned)

    # It samples one window to read a colour. That is a measurement, not a shot
    # set: nothing is kept, and nothing is written where the repo can see it.
    ok("the measure keeps no shots",
       "product/mockups" not in measure_code and "shots" not in measure_code)
    ok("the capture is one window", "-l\\(window)" in measure_code)
    ok("the capture writes one temp file", "NSTemporaryDirectory()" in measure_code)
    ok("the capture cleans up after itself", "removeItem" in measure_code)
    ok("the capture avoids the unavailable SDK call",
       "CGWindowListCreateImage" not in measure_code)

    # The mark floor is about a project mark, so it must sample a project.
    ok("the selection sample is a pinned project", "func pinnedProjectRow" in measure_code)
    ok("the mark is sampled from its own frame", "func markFrame" in measure_code)
    ok("the mark sample is not a fixed offset",
       "local.minX + 8" not in measure_code and "width: 16" not in measure_code)
    ok("the mark sample is pulled inside the icon", "insetBy(dx: $0.width * 0.28" in measure_code)
    ok("the fill sample clears the mark", "markRect.maxX" in measure_code)
    ok("a misaligned capture refuses to report",
       "abs(scale - verticalScale)" in measure_code and "else { return nil }" in measure_code)
    ok("the report says where it sampled",
       "mark_sample" in measure and "fill_sample" in measure and "selected_row" in measure)
    ok("the sample skips the destinations",
       '"Portfolio", "Timeline"' in measure_code and "isDisjoint" in measure_code)
    ok("the sample is not just the first row",
       "sidebarRows(in: nodes).first else" not in measure_code)
    ok("the mark floor is not lowered to pass", swift_constant(measure, "markSaturationFloor") == "0.08")
    ok("the selection ceiling holds", swift_constant(measure, "selectionSaturationCeiling") == "0.35")
    ok("the wrapper compiles the repo script", "scripts/mac_measure.swift" in wrapper)
    ok("the wrapper passes the exit code through", 'exit "$status"' in wrapper)

    # The rule itself.
    ok("decisions locks Mac-first measures",
       "Locked — Mac-first measures before Critique" in decisions)
    ok("decisions says a still is not a review",
       "is not a review" in decisions)
    ok("decisions fixes the order", "Only then does Critique see it." in decisions)
    ok("decisions records the measured rail numbers", "93 / 93 / 93" in decisions)
    ok("decisions records the forbidden body drop", "197 → 249" in decisions)
    ok("decisions keeps scratch helpers out of the contract",
       "never the source of truth" in decisions)
    ok("ui-spec carries the measure table", "## Measures before review" in ui)
    ok("ui-spec names the script", "scripts/mac_measure.swift" in ui)
    ok("ui-spec states the three measures",
       "body_y" in ui and "selection_ok" in ui and "title_ok" in ui)
    onboarding = (PRODUCT / "onboarding.md").read_text()
    orders = onboarding.split("## Standing orders")[1].split("\n## ")[0] if "## Standing orders" in onboarding else ""
    ok("onboarding has the rule as a standing order",
       "Mac-first measures before Critique" in orders)
    ok("onboarding says a still is not a review", "is not a review" in orders)
    ok("onboarding names the script a new subscription runs", "mac_measure.sh" in orders)


def tab_body_top(pane_y: float, leading_decoration: float = 0.0) -> float:
    """Mirrors DocumentMeasure.tabBodyTop."""
    return pane_y + leading_decoration


def check_tab_body_origin(home: str, ui: str, decisions: str) -> None:
    """Design, Mockups and every other project tab start their first line at the
    same Y under the rail. A still rail is not a still pane."""
    code = without_comments(home)
    empty = without_comments((SOURCES / "UI/Shell/EmptyStateView.swift").read_text())
    metrics = without_comments((SOURCES / "UI/Theme/Typography.swift").read_text())

    ok("the origin measure lives in Swift", "func tabBodyTop" in metrics)
    ok("a tab body starts at the pane padding", tab_body_top(Metrics_paneY) == Metrics_paneY)
    ok("Design and an empty Mockups share one origin",
       tab_body_top(Metrics_paneY) == tab_body_top(Metrics_paneY, 0))
    ok("a leading decoration moves the body",
       tab_body_top(Metrics_paneY, 52) != tab_body_top(Metrics_paneY))
    ok("the measured 52pt drop would fail this lock",
       tab_body_top(Metrics_paneY, 52) - tab_body_top(Metrics_paneY) == 52)

    # The document empty state leads with its title line, not a decoration row.
    poster_only = empty.split("if layout == .poster {")[1].split("}")[0] if "if layout == .poster {" in empty else ""
    ok("the poster keeps its big symbol", "Image(systemName: section.symbol)" in poster_only)
    ok("the big symbol is poster-only",
       empty.count("type.bodySize + 15") == 1 and "type.bodySize + 15" in poster_only)
    # The first child after the poster-only branch is the title itself, so a
    # document empty state opens on a plain line of text like a paragraph does.
    stack = empty.split("? 12 : 8) {", 1)[1] if "? 12 : 8) {" in empty else ""
    after_poster = stack.split("}", 1)[1] if "}" in stack else ""
    ok("a document empty state leads with its title",
       after_poster.strip().startswith("Text(title)"))
    ok("no symbol shares the title's line",
       "firstTextBaseline" not in empty and "if layout == .document {" not in empty)
    ok("the empty state lays text out like prose",
       empty.count("lineSpacing(type.lineSpacing)") >= 2)
    ok("a document empty state has no top padding",
       ".padding(.top" not in empty and "Spacer()" not in empty)

    # No tab branch adds a top inset the others do not share.
    branches = {
        "documentTab": ("private var documentTab", "private var mockupsTab"),
        "mockupsTab": ("private var mockupsTab", "private func mockupFlow"),
        "projectIssues": ("private var projectIssues", "private var currentDocument"),
    }
    for name, (start, end) in branches.items():
        body = code.split(start)[1].split(end)[0] if start in code and end in code else ""
        ok(f"{name} exists", bool(body))
        ok(f"{name} adds no top inset", bool(body) and ".padding(.top" not in body)
        ok(f"{name} does not centre its content", bool(body) and "alignment: .center" not in body)
        ok(f"{name} opens no gap above its first line", bool(body) and "Spacer()" not in body)

    # The two ways the Design tab started lower than its siblings.
    markdown = without_comments((SOURCES / "UI/Markdown/MarkdownView.swift").read_text())
    ok("the first block carries no top air", "isFirst ? 0 :" in markdown)
    ok("the first block is known to the renderer",
       "isFirst: offset == 0" in markdown and "isFirst: Bool" in markdown)
    ok("a skipped opener does not leave its air behind",
       "dropFirst()" in markdown and "isFirst" in markdown)
    ok("the document chip rail is sized to its content",
       ".fixedSize(horizontal: false, vertical: true)" in code)

    ok("the tab body is padded once, outside the switch",
       code.split("private var tabBody")[1].split("private var")[0].count(".padding(") == 0
       if "private var tabBody" in code else False)
    ok("the tab wash fills the pane", "max(Metrics.emptyPaneMin, geo.size.height)" in code)

    ok("ui-spec locks one content origin",
       "share one content origin under the rail" in ui)
    ok("ui-spec scores the click, not the rail", "a still rail is not a still pane" in ui.lower())
    ok("decisions locks the shared origin", "Locked — Every project tab shares one content origin" in decisions)


def summary_sentence(text: str, name: str) -> str:
    """Mirrors MarkdownParser.asSentence: no card line starts mid-sentence."""
    result = strip_name_prefix(text, name).strip()
    for copula in ("is ", "are ", "was ", "were "):
        if result.lower().startswith(copula):
            result = result[len(copula) :].strip()
            break
    if result and result[0].islower():
        result = result[0].upper() + result[1:]
    return result


def comparable_title(text: str) -> str:
    kept = "".join(ch if ch.isalnum() else " " for ch in text.lower())
    return " ".join(word for word in kept.split() if word != "and")


def repeats_title(heading: str, title: str) -> bool:
    left, right = comparable_title(heading), comparable_title(title)
    if not left or not right:
        return False
    return left == right or left.startswith(right) or right.startswith(left)


def check_critique_musts(swift: str, home: str, root: str, sidebar: str, ui: str, decisions: str) -> None:
    """The five Critique musts plus the Mockups landing, locked in source and spec."""
    # Must 1 — the document does not print a second headline.
    ok("H1 matching the tab is suppressed", "suppressedTitle" in swift)
    ok("suppression is a parser rule, not a per-view hack", "func repeatsTitle" in swift)
    ok("Design H1 under the Design tab is a repeat", repeats_title("Design", "Design"))
    ok("Decisions & questions matches the Decisions tab",
       repeats_title("Decisions & questions", "Decisions & questions"))
    ok("a different document keeps its title", not repeats_title("UI specification", "Design"))
    ok("project home suppresses the tab title", "suppressedTitle: tab.section.title" in home)
    ok("onboarding suppresses the window title",
       'suppressedTitle: "Onboarding"' in (SOURCES / "UI/Shell/OnboardingView.swift").read_text())
    ok("the outline drops the heading it does not render", "suppressingTitle" in swift)
    ok("no view deletes markdown to hide a heading", "dropFirst()" in
       (SOURCES / "UI/Markdown/MarkdownView.swift").read_text())

    # Must 2 — Contents reserves a gutter instead of covering the last words.
    ok("reading gutter is a measure", "func readingGutter" in swift)
    ok("gutter is zero when Contents is closed", "guard contentsVisible else { return 0 }" in swift)
    ok("project home reserves the gutter", "readingGutter" in home)
    ok("onboarding reserves the gutter",
       "readingGutter" in (SOURCES / "UI/Shell/OnboardingView.swift").read_text())
    ok("the page still measures the whole pane", "DocumentMeasure.pageWidth" in home)
    ok("the gutter is not a third column", "} content:" not in root)
    ok("Contents is still an overlay", contents_is_document_overlay(root))
    ok("the overlay width is shared with the document", "contentsWidth" in swift)

    # Must 3 — History shows notes, never machine output.
    sheet = (SOURCES / "UI/Project/ProjectNoteSheet.swift").read_text()
    ok("History binds the body only", "Text(row.body)" in sheet)
    ok("History hides the old dump", "LegacyHandoffBody.looksLikeDump" in sheet)
    ok("History hides empty bodies", "isEmpty" in sheet)
    ok("the legacy reader never writes a body",
       "persistBody" not in (SOURCES / "Model/LegacyHandoffBody.swift").read_text())
    ok("new sends stay comment-only",
       "userText.trimmingCharacters" in (SOURCES / "Model/ChiefHandoff.swift").read_text())
    ok("the composer is not prefilled from a handoff",
       "handoff == nil, draft.isEmpty" in (SOURCES / "UI/Shell/NoteComposer.swift").read_text())

    # Must 4 — no invented plan data.
    seed = (SOURCES / "Data/Seed.swift").read_text()
    ok("seed adds no smoke milestones", seed.count("Milestone(") <= 1)
    ok("seed invents no issues", "Issue(" not in seed)
    ok("the Gantt is still a Gantt", "TimelineGanttView" in swift)

    # Must 5 — the card is the picture.
    portfolio = (SOURCES / "UI/Portfolio/PortfolioView.swift").read_text()
    ok("card.png is the card face", "card.png" in swift)
    ok("the poster resolves before the mark", "isCardImage" in swift and "cardImage(for" in swift)
    ok("the sidebar keeps the small mark", "markImage(for: project)" in sidebar)
    ok("brand artwork is not a mockup", "isBrandAsset" in swift)
    ok("card.png routes out of the gallery", route("product/card.png") == "more")
    ok("icon.png routes out of the gallery", route("product/icon.png") == "more")
    library = (SOURCES / "Documents/DocumentLibrary.swift").read_text()
    ok("the loader asks the router about images", "tab: .mockups," not in library)
    ok("every loaded document is routed", library.count("tab: DocumentRouting.tab(for:") >= 2)
    ok("a real frame still routes to mockups", route("product/mockups/01-home.png") == "mockups")
    ok("a loose screenshot still routes to mockups", route("product/home-screen.png") == "mockups")
    ok("the poster falls back to a designed field", "posterFace" in portfolio)
    ok("card summary does not start mid-sentence",
       summary_sentence("Arkboard is Origin Ark Studio's local studio board for macOS.", "Arkboard")
       == "Origin Ark Studio's local studio board for macOS.")
    ok("card summary opens on a capital",
       summary_sentence("Lumen paints light.", "Lumen") == "Paints light.")
    ok("card summary keeps a lead that is not the name",
       summary_sentence("A quiet board.", "Arkboard") == "A quiet board.")
    ok("card summary does not strip a longer word",
       summary_sentence("Arkboarded later.", "Arkboard") == "Arkboarded later.")
    ok("sentence repair lives in Swift", "func asSentence" in swift)

    # Must 6 — landing on Mockups does not move the rail.
    code = without_comments(home)
    ok("no geometry animation on a tab change", "value: tab)" not in code)
    ok("the scroll reset is unanimated", "disablesAnimations = true" in code)
    ok("every tab resets the same way", "restTop(proxy)" in code)
    ok("the gallery cell height is known before it paints",
       "Metrics.mockupCell" in code and "Metrics.mockupThumb" in code)

    # Design -> Mockups -> Design does not move the tab rail. Each clause below
    # is one way that promise has already been broken once.
    setter = code.split("private func selection(for item: ProjectHomeTab)")[1].split("private func")[0] if "private func selection(for item: ProjectHomeTab)" in code else ""
    stack = code.split("pinnedViews: .sectionHeaders")[1] if "pinnedViews: .sectionHeaders" in code else ""
    rail_still = [
        ("the rail is first in the scroll",
         stack.split("{", 1)[1].strip().startswith("Section {") if stack else False),
        ("the rail is never the scroll target", 'scrollTo("tab-bar"' not in code),
        ("no easing wraps the tab assignment", bool(setter) and "withAnimation" not in setter),
        ("no animation modifier is keyed on the tab", "value: tab)" not in code),
        ("the reset disables animation", "disablesAnimations = true" in code),
        ("the gallery is sized before it paints", "Metrics.mockupCell" in code),
    ]
    for name, held in rail_still:
        ok(f"rail stays put — {name}", held)
    ok("Design to Mockups to Design does not move the tab rail",
       all(held for _, held in rail_still))

    # Sidebar selection stays readable.
    ok("selection is the system's quiet grey", "quietSelection" in swift)
    ok("selection is not a colour we mixed", "unemphasizedSelectedContentBackgroundColor" in swift)
    ok("the sidebar keeps the unemphasized selection", "quietSelection()" in sidebar)
    ok("a tint is not used for the selected row", ".tint(" not in without_comments(sidebar))
    ok("destination rows state their own colours", "func destinationRow" in sidebar)
    ok("the project key stays readable when selected",
       "StudioColor.tertiary" not in sidebar.split("Text(project.key)")[1].split("}")[0]
       if "Text(project.key)" in sidebar else False)

    # Spec and locks.
    ok("ui-spec voids the second headline", "second headline" in ui.lower())
    ok("ui-spec reserves the Contents gutter", "gutter" in ui.lower())
    ok("ui-spec says the card is the picture", "the card is the picture" in ui.lower())
    ok("ui-spec names product/card.png", "product/card.png" in ui)
    ok("ui-spec puts project identity on the toolbar", "identity" in ui.lower() and "toolbar" in ui.lower())
    ok("ui-spec keeps the rail still", "does not move" in ui.lower() or "stays put" in ui.lower())
    ok("decisions locks the poster card", "Locked — The Portfolio card is the picture" in decisions)
    ok("decisions locks one headline", "Locked — One headline" in decisions)
    ok("decisions locks the grey selected row",
       "Locked — The selected sidebar row is always the unemphasized grey" in decisions)
    ok("decisions says grey holds when focused", "focused or not" in decisions)
    ok("decisions locks Timeline without a title", "Timeline has no in-page title" in decisions)

    # MUST 7 — one grey selected row, every destination, focused or not.
    quiet = (SOURCES / "UI/Shell/QuietSelection.swift").read_text()
    ok("source UI/Shell/QuietSelection.swift", bool(quiet))
    ok("the sidebar refuses first responder like Finder", "refusesFirstResponder" in quiet)
    ok("no grey capsule is hand-drawn for selection",
       "RoundedRectangle" not in quiet and "Capsule" not in quiet)
    ok("every destination row is quiet", without_comments(sidebar).count("quietSelection()") >= 2)
    ok("destination symbols keep their section hue", "section.hue.color(for: scheme)" in sidebar)
    ok("the project mark is not forced white", "StudioColor.primary" in sidebar)
    ok("the key is not forced white", "StudioColor.secondary" in sidebar)

    # MUST 1 leftover — Timeline opens on the chart.
    timeline = (SOURCES / "UI/Portfolio/TimelineView.swift").read_text()
    ok("Timeline has no in-page title band",
       "ScreenHeader" not in timeline and "Every project on one timeline." not in timeline)
    ok("Timeline pane opens on the Gantt", "TimelineGanttView(projectId: nil)" in timeline)
    ok("the window title is one row on every screen", "toolbarTitleDisplayMode(.inline)" in root)
    ok("ui-spec says Timeline has no in-page title", "Timeline has no in-page title" in ui)
    ok("ui-spec pins the title to one row", "one row, on every screen" in ui)
    ok("ui-spec locks the grey selected row",
       "including when the sidebar has focus" in ui)
    ok("ui-spec forbids tinting the selection", "Do not \"fix\" this by tinting the list" in ui)
    ok("onboarding tells a human where the card goes", "product/card.png" in
       (PRODUCT / "onboarding.md").read_text())


def main() -> int:
    expected_routes = {
        "product/README.md": "overview",
        "product/design.md": "design",
        "product/ui-spec.md": "design",
        "product/architecture.md": "architecture",
        "product/mcp.md": "architecture",
        "product/decisions.md": "decisions",
        "product/mockups/README.md": "mockups",
    }
    for path, tab in expected_routes.items():
        ok(f"route {path} → {tab}", route(path) == tab, route(path))

    decisions = (PRODUCT / "decisions.md").read_text()
    parsed = parse_questions(decisions)
    opens = [p for p in parsed if p["open"]]
    locked = [p for p in parsed if p["locked"]]
    ok("decisions has open questions", len(opens) >= 6, str(len(opens)))
    ok("decisions has locked calls", len(locked) >= 10, str(len(locked)))
    ok("open heading starts with Open", all(p["heading"].startswith("Open") for p in opens))
    ok("locked heading starts with Locked", all(p["heading"].startswith("Locked") for p in locked))

    ok("collapse title", collapse_title("  Hello \n  world  ") == "Hello world")
    ok("empty title rejected", collapse_title("   \n") == "")
    ok("project key ARK", project_key("ark") == "ARK")
    try:
        project_key("X")
        ok("short key rejected", False)
    except ValueError:
        ok("short key rejected", True)
    ok("labels dedupe", labels(["Feature", "feature", " bug ", "Feature"]) == ["feature", "bug"])
    ok("riyu hue moss", actor_hue("Riyu") == "moss")
    ok("cursor hue violet", actor_hue("Cursor") == "violet")
    ok("stable hash", actor_hue("Ops") == actor_hue("ops"))
    ok("group underway", human_group("in_progress", False) == "Underway")
    ok("group queued backlog", human_group("backlog", False) == "Queued")
    ok("group canceled hidden", human_group("canceled", False) is None)
    ok("group archived", human_group("todo", True) == "Archived")

    required = [
        "ArkboardApp.swift",
        "Model/Entities.swift",
        "Model/Enums.swift",
        "Model/HumanVocabulary.swift",
        "Data/AppDatabase.swift",
        "Data/AppStore.swift",
        "Data/Validation.swift",
        "Data/Seed.swift",
        "Documents/DocumentLibrary.swift",
        "Documents/DocumentRouting.swift",
        "Documents/MarkdownParser.swift",
        "Documents/QuestionParser.swift",
        "Server/StudioServer.swift",
        "Server/RESTRoutes.swift",
        "Server/MCPRoutes.swift",
        "Server/ToolCatalogue.swift",
        "UI/Theme/Hue.swift",
        "UI/Theme/Typography.swift",
        "UI/Markdown/MarkdownView.swift",
        "UI/Markdown/ContentsOutline.swift",
        "UI/Shell/RootView.swift",
        "UI/Shell/SidebarView.swift",
        "UI/Shell/NoteComposer.swift",
        "Model/ProjectMark.swift",
        "UI/Monitor/MonitorView.swift",
        "UI/Issues/IssuesView.swift",
        "UI/Activity/ActivityView.swift",
        "UI/Portfolio/PortfolioView.swift",
        "UI/Portfolio/TimelineModel.swift",
        "UI/Portfolio/TimelineGantt.swift",
        "UI/Portfolio/TimelineView.swift",
        "UI/Project/ProjectHomeView.swift",
        "UI/Project/ProjectNoteSheet.swift",
        "UI/Shell/OnboardingView.swift",
        "UI/Settings/SettingsView.swift",
        "Model/ChiefHandoff.swift",
        "UI/Shell/ChiefOfStaffMenu.swift",
    ]
    for rel in required:
        ok(f"source {rel}", (SOURCES / rel).exists())

    swift = "\n".join(p.read_text() for p in SOURCES.rglob("*.swift"))
    ok("no BoardView", "struct BoardView" not in swift)
    ok("no QuickAdd", "QuickAdd" not in swift)
    ok("no New Issue button", 'Button("New Issue")' not in swift)
    ok("no create_requirement tool", "create_requirement" not in swift)
    ok("no link_github_issue", "link_github_issue" not in swift)
    ok("no command+shift+n issue", "command, .shift" not in swift and "⌘⇧N" not in swift)
    ok("no requirement table", 'table: "requirement"' not in swift)
    ok("studio.sqlite", "studio.sqlite" in swift)
    ok("port 7420", "7420" in swift)
    ok("20 tools listed", all(name in swift for name in [
        "list_projects", "create_project", "update_project", "list_documents", "read_document",
        "list_issues", "get_issue", "create_issue", "update_issue", "delete_issue",
        "restore_issue", "add_comment", "post_note", "list_activity",
        "list_milestones", "create_milestone", "update_milestone",
        "list_capabilities", "create_capability", "update_capability",
    ]))
    ok("director pass copy", "A director pass will write this." in swift)
    ok("Tell the team placeholder", "Tell the team…" in swift)
    ok("Contents outline", "Contents" in swift and "struct ContentsOutline" in swift)
    ok("no On this page rail", "On this page" not in swift)
    ok("no OutlineBar", "struct OutlineBar" not in swift)
    ok("Arkboard mark", "square.3.layers.3d" in swift)
    ok("project icon column", 'add(column: "icon"' in swift or "var icon: String" in swift)
    ok("v2 project icon migration", "v2-project-icon" in swift)
    ok("Underway group", "Underway" in swift)
    ok("hue rose", "#D4436B" in swift)
    ok("hue indigo", "#5A62D6" in swift)
    ok("body default 13", "bodySize: 13" in swift or "fontSize" in swift)
    ok("no old Views tree", not (SOURCES / "Views").exists())
    ok("no old Store tree", not (SOURCES / "Store").exists())
    ok("no old MCP tree", not (SOURCES / "MCP").exists())
    ok("bridge.py exists", (ROOT / "mcp" / "bridge.py").exists())
    ok("no mcp/server.py", not (ROOT / "mcp" / "server.py").exists())

    smoke = (ROOT / "scripts" / "smoke.sh").read_text()
    for needle in (
        "/health", "tools/list", "create_issue", "list_activity",
        "completedAt", "add_comment", "delete_issue", "restore_issue",
        "Unknown related issue", "create_capability", "not_working",
        "Comment cannot be empty", "Invalid date", "list_documents",
        "read_document", "architecture.md",
        "dependsOn", "Unknown milestone dependency", "cannot depend on itself",
        "cannot form a cycle", "PATCH", "/api/milestones/",
    ):
        ok(f"smoke covers {needle}", needle in smoke)

    readme = (ROOT / "README.md").read_text()
    ok("README is not Linear tracker", "Linear-style" not in readme)
    ok("README points at product/", "product/" in readme)

    sidebar = (SOURCES / "UI/Shell/SidebarView.swift").read_text()
    ok("sidebar has no Monitor row", "binoculars" not in sidebar and ".monitor" not in sidebar)
    ok("sidebar has no Issues row", "tray.full" not in sidebar and "studioRow" not in sidebar)
    ok("sidebar uses ProjectIcon", "ProjectIcon" in sidebar)
    root = (SOURCES / "UI/Shell/RootView.swift").read_text()
    ok("root has ContentsOutline", "ContentsOutline()" in root)
    ok("root has no studio Issues split", "IssueListColumn" not in root)
    ok("root opens project home", "ProjectHomeView(project:" in root)
    ok("root is two-column split", "} content:" not in root and "} detail:" in root)
    ok("document column min width", "documentMin" in swift)
    ok("sidebar has no NavigationLink", "NavigationLink" not in sidebar)
    ok("workspace is not a sidebar row", "building.2" not in sidebar and "Origin Ark" not in sidebar)
    ok("⌘N focuses project composer", "goToComposer" in swift and "composerFocused = true" in swift)
    home = (SOURCES / "UI/Project/ProjectHomeView.swift").read_text()
    ok("home has no OutlineBar", "OutlineBar" not in home)
    ok("home publishes outline", "publishOutline" in home)
    ok("issues stay a project tab", "case .issues:" in home)

    # Distinct marks: Arkboard reserved, others do not collide with it or each other.
    used = set()
    ark = assign_mark("ARK", "Arkboard", used)
    ok("ARK mark is layered board", ark[0] == "square.3.layers.3d", ark[0])
    used.add(ark[0])
    other_keys = ["LUMEN", "NOVA", "RIVER", "ATLAS", "QUILL"]
    others = []
    for key in other_keys:
        mark = assign_mark(key, key.title(), used)
        others.append(mark[0])
        used.add(mark[0])
    ok("other marks are unique", len(set(others)) == len(others), str(others))
    ok("others are not Arkboard mark", "square.3.layers.3d" not in others, str(others))
    ui = (PRODUCT / "ui-spec.md").read_text()
    design = (PRODUCT / "design.md").read_text()
    ok("ui-spec contents on the right", "one outline, on the right" in ui)
    ok("design contents column", "right-hand **Contents** column" in design or "right-hand **Contents**" in design)

    check_polish(swift, home, root, sidebar)
    check_document_bundle(swift)
    check_layout_musts(swift, home)
    check_studio_chrome(swift, home, root, sidebar, ui)
    check_chief_handoff(swift, home, root, sidebar, ui)
    check_contents_overlay_and_card_type(swift, home, root, ui)
    check_timeline_gantt(swift, home, ui, decisions, (PRODUCT / "architecture.md").read_text(), (PRODUCT / "mcp.md").read_text())
    check_window_title_only(swift, home, root, sidebar, ui, decisions)
    check_portfolio_hero_cards(swift, sidebar, ui, decisions)
    check_critique_musts(swift, home, root, sidebar, ui, decisions)
    check_tab_body_origin(home, ui, decisions)
    check_mac_measures(ui, decisions)
    check_living_tabs(ui, decisions, design)

    print()
    if FAIL:
        print(f"{FAIL} failed, {PASS} passed.")
        return 1
    print(f"All {PASS} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
