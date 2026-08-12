# Arkboard v1 — Morning Handoff (2026-08-12 overnight polish)

## Status: Working + polished

Ship criteria met, plus overnight polish committed to `main`.

## Open the app

```bash
cd "/Users/dilipreddy/Origin Ark Studio/arkboard"
./scripts/run.sh
# or: open build/DerivedData/Build/Products/Debug/Arkboard.app
```

**Important:** Launch via `open …/Arkboard.app` (or Xcode Run), not the raw Mach-O binary.

## Smoke test (app must be running)

```bash
./scripts/smoke.sh
```

Checks: `/health`, MCP `tools/list`, MCP `create_issue` + `list_issues`, REST list.

## MCP / API

- Health: `http://127.0.0.1:7420/health`
- REST: `http://127.0.0.1:7420/api/projects`, `/api/issues`
- MCP JSON-RPC: `POST http://127.0.0.1:7420/mcp`
- Cursor stdio bridge: `mcp/server.py`

## Overnight polish landed

- Empty states for no projects / no issues / no search matches
- Board: drop-on-card inserts before target (within-column reorder) without breaking column append drops
- Labels: tokenized chip field (Return/comma) in detail + quick add
- `AppStore.dataRevision` bumps on reload so MCP mutations refresh list/board reliably
- Issue detail syncs status/priority/labels from external updates without always clobbering in-progress title/description drafts
- `scripts/smoke.sh` for health + MCP create/list

## Still rough / next

- MCP is JSON-RPC over HTTP, not full Streamable HTTP/SSE MCP SDK
- No rich markdown preview
- No app icon / notarization / sandboxed distribution
- Inbox board mixes projects; per-project board ordering is cleaner
- Direct binary launch (without `open`) can be flaky for the embedded HTTP server

## Data

`~/Library/Application Support/Arkboard/arkboard.sqlite`
