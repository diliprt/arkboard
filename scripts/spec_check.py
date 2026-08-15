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


MONTHS = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)


def period_start(year: int, month: int, day: int, scale: str) -> tuple[int, int, int]:
    """Monday-start week, first of month, 1 January. Mirrors TimelineCalendarMath."""
    from datetime import date, timedelta
    current = date(year, month, day)
    if scale == "week":
        start = current - timedelta(days=current.weekday())
        return start.year, start.month, start.day
    if scale == "month":
        return year, month, 1
    if scale == "year":
        return year, 1, 1
    raise ValueError(scale)


def shift_period(year: int, month: int, day: int, scale: str, delta: int) -> tuple[int, int, int]:
    from datetime import date
    if scale == "week":
        from datetime import timedelta
        start = date(year, month, day) + timedelta(weeks=delta)
        return start.year, start.month, start.day
    if scale == "month":
        index = year * 12 + (month - 1) + delta
        next_year, next_month = divmod(index, 12)
        return next_year, next_month + 1, 1
    if scale == "year":
        return year + delta, 1, 1
    raise ValueError(scale)


def period_title(year: int, month: int, day: int, scale: str) -> str:
    if scale == "week":
        return f"Week of {day} {MONTHS[month - 1]}"
    if scale == "month":
        return f"{MONTHS[month - 1]} {year}"
    if scale == "year":
        return str(year)
    raise ValueError(scale)


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


def today_index(dates: list[int], now: int) -> int:
    """Index of the single Today rule: before the first future event."""
    for i, date in enumerate(dates):
        if date > now:
            return i
    return len(dates)


def check_polish(swift: str, home: str, root: str, sidebar: str) -> None:
    """product/polish.md must-fix (and cheap should-fix) source checks."""
    now = 1_000
    ok("D2 today at top when all future", today_index([1_100, 1_200], now) == 0)
    ok("D2 today at end when all past", today_index([800, 900], now) == 2)
    ok("D2 today between past and future", today_index([800, 900, 1_100, 1_200], now) == 2)
    ok("D2 today empty list", today_index([], now) == 0)

    def today_marks(dates: list[int], current: int) -> list[str]:
        insert = today_index(dates, current)
        marks: list[str] = []
        for i, _ in enumerate(dates):
            if i == insert:
                marks.append("today")
            marks.append("event")
        if insert == len(dates):
            marks.append("today")
        return marks

    ok("D2 exactly one today mixed", today_marks([800, 900, 1_100, 1_200], now).count("today") == 1)
    ok("D2 exactly one today all past", today_marks([800, 900], now).count("today") == 1)
    ok("D2 exactly one today all future", today_marks([1_100, 1_200], now).count("today") == 1)
    ok("D2 today before first future event", today_marks([800, 1_100], now) == ["event", "today", "event"])

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
    ok("O2 Contents width range", "outlineMin" in root and "outlineMax" in root)
    ok("T3 question chips wrap", "FlowLayout" in home)
    ok("D2 single todayIndex", "todayIndex" in swift and "shouldShowToday" not in swift)
    ok("D3 TimelineSpine has no local ScrollViewReader", "ScrollViewReader" not in (SOURCES / "UI/Portfolio/TimelineSpine.swift").read_text())
    ok("D3 calendar is the timeline reading view", "TimelineScale" in swift and "TimelineCalendarView" in swift)
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
    ok("Must A mockups lands on the tab rail", ".mockups" in tab_change and 'scrollTo("tab-bar"' in tab_change)
    ok("Must A tab rail is a scroll anchor", '.id("tab-bar")' in home)
    ok("Must A landing is not a user scroll-to-recover", "tab-bar" in home and "mockups" in tab_change)
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
    ok("Must A scroll-to-tab-bar kept", 'scrollTo("tab-bar"' in home)
    ok("#15 ensureDocuments kept", "ensureDocuments" in home)
    ok("ui-spec project-home empties share the document edge", "share the document left edge" in ui or "shares the document left edge" in ui)


def check_studio_chrome(swift: str, home: str, root: str, sidebar: str, ui: str) -> None:
    """Portfolio destination, pins, master Timeline calendar, quiet project home."""
    ok("week start is Monday of that week", period_start(2026, 8, 15, "week") == (2026, 8, 10))
    ok("month start is the first", period_start(2026, 8, 15, "month") == (2026, 8, 1))
    ok("year start is 1 January", period_start(2026, 8, 15, "year") == (2026, 1, 1))
    ok("shift week", shift_period(2026, 8, 10, "week", 1) == (2026, 8, 17))
    ok("shift month", shift_period(2026, 8, 1, "month", -1) == (2026, 7, 1))
    ok("shift year", shift_period(2026, 1, 1, "year", 1) == (2027, 1, 1))
    ok("week title", period_title(2026, 8, 10, "week") == "Week of 10 August")
    ok("month title", period_title(2026, 8, 1, "month") == "August 2026")
    ok("year title", period_title(2026, 1, 1, "year") == "2026")
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
    ok("portfolio card shows local path", "local ·" in portfolio)
    ok("portfolio card shows github remote", "github ·" in portfolio)
    ok("portfolio card has doc pills", "Design" in portfolio and "Architecture" in portfolio and "Mockups" in portfolio and "Decisions" in portfolio)
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

    calendar = (SOURCES / "UI/Portfolio/TimelineCalendar.swift").read_text() if (SOURCES / "UI/Portfolio/TimelineCalendar.swift").exists() else ""
    ok("timeline calendar source exists", bool(calendar))
    ok("timeline scale control Week Month Year",
       "Week" in calendar and "Month" in calendar and "Year" in calendar)
    ok("timeline calendar math lives in Swift", "periodStart" in calendar or "TimelineCalendarMath" in calendar)
    ok("master timeline uses the calendar", "TimelineCalendarView" in swift)
    ok("project timeline tab uses the calendar", "TimelineCalendarView" in home)
    ok("click-through opens project Timeline", "pendingProjectTab = .timeline" in swift or "openProjectTimeline" in swift)

    ok("pinned column exists", "var pinned: Bool" in swift)
    ok("v3 pin migration", "v3-project-pinned" in swift)
    ok("create project accepts pinned", "pinned" in (SOURCES / "Server/ToolCatalogue.swift").read_text())
    ok("update_project exists so agents can pin", "update_project" in swift)
    ok("project JSON includes pinned", '"pinned"' in (SOURCES / "Data/JSONPayload.swift").read_text())

    header = ""
    if "private var projectHeader" in home:
        header = home.split("private var projectHeader")[1].split("private var tabBar")[0]
    ok("project home has a thin header", "private var projectHeader" in home)
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
    ok("ui-spec Timeline is a calendar", "Week / Month / Year" in ui or "Week, Month, Year" in ui)
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
        "UI/Portfolio/TimelineCalendar.swift",
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

    print()
    if FAIL:
        print(f"{FAIL} failed, {PASS} passed.")
        return 1
    print(f"All {PASS} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
