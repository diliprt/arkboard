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
    ok("SB1 New Project is not a toolbar item",
       "folder.badge.plus" in sidebar and ".toolbar" not in sidebar and "ToolbarItem" not in sidebar)
    ok("SB1 New Project lives in the sidebar footer",
       "folder.badge.plus" in sidebar and "safeAreaInset" in sidebar)
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
    ok("D3 pane scrolls to today", 'scrollTo("today"' in home)
    ok("D3 TimelineSpine has no local ScrollViewReader", "ScrollViewReader" not in (SOURCES / "UI/Portfolio/TimelineSpine.swift").read_text())
    ok("D4 issue identifier not duplicated in title",
       "issue.identifier)  \\(issue.title)" not in swift)
    ok("E1 empty state can fill the pane", "minHeight" in (SOURCES / "UI/Shell/EmptyStateView.swift").read_text())


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
        "UI/Project/ProjectHomeView.swift",
        "UI/Settings/SettingsView.swift",
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
    ok("19 tools listed", all(name in swift for name in [
        "list_projects", "create_project", "list_documents", "read_document",
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
    ok("sidebar lists projects", "ForEach(store.projects)" in sidebar)
    ok("sidebar uses ProjectIcon", "ProjectIcon" in sidebar)
    root = (SOURCES / "UI/Shell/RootView.swift").read_text()
    ok("root has ContentsOutline", "ContentsOutline()" in root)
    ok("root has no studio Issues split", "IssueListColumn" not in root)
    ok("root opens project home", "ProjectHomeView(project:" in root)
    ok("root is two-column split", "} content:" not in root and "} detail:" in root)
    ok("document column min width", "documentMin" in swift)
    ok("sidebar has no NavigationLink", "NavigationLink" not in sidebar)
    ok("workspace is caption not a row", 'font(type.caption)' in sidebar and "building.2" in sidebar)
    ok("⌘N focuses project composer", "goToComposer" in swift and "composerFocused = true" in swift)
    home = (SOURCES / "UI/Project/ProjectHomeView.swift").read_text()
    ok("home has no OutlineBar", "OutlineBar" not in home)
    ok("home publishes outline", "publishOutline" in home)
    ok("home composer on project", "NoteComposer(projectKey:" in home)
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
    ok("ui-spec sidebar is projects", "clean portfolio of projects" in ui)
    ok("ui-spec contents on the right", "one outline, on the right" in ui)
    ok("design contents column", "right-hand **Contents** column" in design or "right-hand **Contents**" in design)

    check_polish(swift, home, root, sidebar)

    print()
    if FAIL:
        print(f"{FAIL} failed, {PASS} passed.")
        return 1
    print(f"All {PASS} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
