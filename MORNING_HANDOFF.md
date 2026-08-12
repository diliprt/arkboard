# Arkboard v1 — Morning Handoff (2026-08-12)

## Status: Working

Ship criteria met:
- [x] App launches on Mac
- [x] Create project/issue in UI (⌘N quick add + New Project)
- [x] List + Board views; SQLite persists across relaunch
- [x] Agent API/MCP list/create/update on `127.0.0.1:7420`
- [x] Pushed to https://github.com/diliprt/arkboard

## Open the app

```bash
cd "/Users/dilipreddy/Origin Ark Studio/arkboard"
./scripts/run.sh
# or: open Arkboard.xcodeproj  → Run
```

Built app path (after build):
`build/DerivedData/Build/Products/Debug/Arkboard.app`

**Important:** Launch via `open …/Arkboard.app` (or Xcode Run), not by invoking the raw Mach-O binary — the GUI activation path is more stable for the embedded HTTP server.

## MCP / API

While the app is running:

- Health: `http://127.0.0.1:7420/health`
- REST: `http://127.0.0.1:7420/api/projects`, `/api/issues`
- MCP JSON-RPC: `POST http://127.0.0.1:7420/mcp`
- Cursor stdio bridge: `mcp/server.py` (see README)

## What's solid
- GRDB schema + seed (ARK / OPS demo data)
- Sidebar Inbox + projects, List/Board, detail editor, comments
- Drag cards between board columns
- Single write path through `AppStore` for UI + MCP

## What's rough / next
- MCP is JSON-RPC over HTTP (tools/list + tools/call), not full Streamable HTTP/SSE MCP SDK
- No board card reordering *within* a column beyond append-to-end drop
- No rich markdown preview; description is plain TextEditor
- Labels edited as comma-separated text (no picker)
- No app icon / notarization / sandboxed distribution
- Direct binary launch (without `open`) was flaky during overnight testing
- UI observation refresh from MCP mutations works but is not polished under heavy agent write load

## Data
`~/Library/Application Support/Arkboard/arkboard.sqlite`
