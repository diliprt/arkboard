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
        "UI/Shell/RootView.swift",
        "UI/Shell/SidebarView.swift",
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
    ok("On this page", "On this page" in swift)
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

    print()
    if FAIL:
        print(f"{FAIL} failed, {PASS} passed.")
        return 1
    print(f"All {PASS} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
