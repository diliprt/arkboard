# Arkboard v1 — Morning Handoff (2026-08-12 Portfolio + Activity)

## Status: Portfolio + Activity + AppIcon shipped

Bird's-eye Portfolio, multi-agent Activity feed, MCP `actor` / `list_activity`, and a real macOS app icon are on `main`.

## Open the app

```bash
cd "/Users/dilipreddy/Origin Ark Studio/arkboard"
./scripts/run.sh
# or: open build/DerivedData/Build/Products/Debug/Arkboard.app
```

**Important:** Launch via `open …/Arkboard.app` (or Xcode Run), not the raw Mach-O binary.

Sidebar: **Portfolio** (above Inbox) · Inbox · **Activity** · Projects.

## Smoke test (app must be running)

```bash
./scripts/smoke.sh
```

Checks: `/health`, MCP `tools/list`, `create_issue` with `actor`, `list_activity`, REST list/activity.

## MCP / API

- Health: `http://127.0.0.1:7420/health`
- REST: `/api/projects`, `/api/issues`, `/api/activity`
- MCP JSON-RPC: `POST http://127.0.0.1:7420/mcp`
- New/updated tools: optional `actor` on create/update/comment/create_project; `list_activity`
- Cursor stdio bridge: `mcp/server.py`

## What landed

- Portfolio cards: totals + status + feature/bug/other; click → project list
- Activity model/table; logged on UI + MCP mutations; feed with agent avatars
- Demo seed (auto if empty) + **Seed demo agent activity** button
- AppIcon from `Resources/arkboard-icon-1024.png` → `Sources/Arkboard/Resources/Assets.xcassets/AppIcon.appiconset`

## Still rough / next

- MCP is JSON-RPC over HTTP, not full Streamable HTTP/SSE MCP SDK
- No rich markdown preview
- No notarization / sandboxed distribution
- macOS may cache Dock icons; `touch` the .app + relaunch if icon looks stale

## Data

`~/Library/Application Support/Arkboard/arkboard.sqlite`
