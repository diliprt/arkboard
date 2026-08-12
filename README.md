# Arkboard

**Local Linear-style issue tracker for macOS** — SwiftUI + SQLite (GRDB) + agent MCP on localhost.

Built for Origin Ark Studio so product direction lives in a real tracker, not chat scrollback. Agents (Cursor / Grok Bot) can list, create, and update issues via a local API — and show up in an **Activity** feed when they talk.

## Features (v1)

- **Portfolio** — Overview cards, shared **Timeline**, and **Milestones** (project or studio-wide)
- **Activity** feed — multi-agent collaboration with bot↔bot visibility (`Product → Ops`), mention/handoff chips
- Projects + Issues (status, priority, labels, comments)
- **List** and **Board** (kanban by status) views for project/Inbox detail work
- Quick add with **⌘N**
- Local SQLite in Application Support
- Local HTTP server on **`127.0.0.1:7420`**
  - REST: `/api/projects`, `/api/issues`, `/api/activity`, `/api/milestones`
  - MCP-shaped JSON-RPC: `POST /mcp` (`tools/list`, `tools/call`)
- Stdio MCP bridge: `mcp/server.py` for Cursor
- Custom macOS **AppIcon** (asset catalog)

### Statuses
`backlog` · `todo` · `in_progress` · `done` · `canceled`

### Priorities
`none` · `low` · `medium` · `high` · `urgent`

### Labels
- An issue may carry **both** `feature` and `bug` (and any other distinct labels) at once.
- Create/update label arrays are **deduped** (trim + case-insensitive) before insert; replace-labels deletes old links then inserts the unique set.
- Duplicate entries like `["feature","feature","bug"]` succeed and become `feature` + `bug`.

### Validation (MCP / REST)
- Comments with multiple `@mentions` (e.g. `@Ops @Comms`) emit **one activity event per distinct** mentioned actor.
- Empty comment body → error `"Comment cannot be empty"` (not the title error).
- Unknown `status` / `priority` on create or update → rejected with a clear error (update does not partially apply other fields when status/priority is invalid).
- Milestone `targetDate`: ISO8601 kept as-is; date-only `yyyy-MM-dd` stored as **noon UTC**; unparseable values (e.g. `not-a-date`) are rejected.
- Titles collapse embedded/consecutive whitespace (including newlines) to single spaces.

## Requirements

- macOS 14+
- Xcode 15+ (Xcode 26 tested)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Optional: Python 3 for the stdio MCP bridge

## Build & run

```bash
cd "/Users/dilipreddy/Origin Ark Studio/arkboard"
./scripts/run.sh
# or: open build/DerivedData/Build/Products/Debug/Arkboard.app
```

**Important:** Launch via `open …/Arkboard.app` (or Xcode Run), not the raw Mach-O binary.

On first launch the app seeds demo projects (**ARK**, **OPS**), sample issues, milestones across the next couple weeks, and a Product ↔ Ops ↔ Comms conversation (with `@mentions`) in Activity, then starts MCP on port **7420**. Existing DBs get milestones/activity auto-seeded when empty or thin; use **Seed demo agent activity** on Portfolio/Activity to re-seed the bot dialogue.

**Click-through:** Portfolio → Overview / Timeline / Milestones · Activity → filter **Mentions/handoffs** to see dual-avatar Product → Ops rows.

### Smoke test

With the app running:

```bash
./scripts/smoke.sh
```

Verifies `/health`, MCP `tools/list`, `create_issue` (with `actor`), `list_activity`, milestone CRUD, `list_bot_thread`, and REST list.

## REST API (curl)

App must be running.

```bash
# Health
curl -s http://127.0.0.1:7420/health | jq

# List projects
curl -s http://127.0.0.1:7420/api/projects | jq

# List issues
curl -s 'http://127.0.0.1:7420/api/issues?projectKey=ARK' | jq

# Activity feed
curl -s 'http://127.0.0.1:7420/api/activity?limit=20' | jq

# Milestones
curl -s 'http://127.0.0.1:7420/api/milestones' | jq

# Create issue
curl -s -X POST http://127.0.0.1:7420/api/issues \
  -H 'Content-Type: application/json' \
  -d '{"projectKey":"ARK","title":"From curl","status":"todo","priority":"high","labels":["agent"],"actor":"Ops"}' | jq

# Update issue
curl -s -X PATCH http://127.0.0.1:7420/api/issues/ARK-1 \
  -H 'Content-Type: application/json' \
  -d '{"status":"in_progress","actor":"Product"}' | jq
```

## MCP for Cursor / agents

### Option A — HTTP JSON-RPC (app embedded)

While Arkboard is open:

```bash
curl -s -X POST http://127.0.0.1:7420/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq
```

Tools: `list_projects`, `create_project`, `list_issues`, `search_issues`, `get_issue`, `create_issue`, `update_issue`, `add_comment`, `list_activity`, `list_milestones`, `create_milestone`, `update_milestone`, `list_bot_thread`.

Mutating tools accept optional **`actor`** (string; default `"Agent"`). `add_comment` parses `@Ops` / `@Product` / `@Comms` mentions into Activity `targetActor` (shown as **Product → Ops**).

### Option B — Cursor stdio bridge

Add to Cursor MCP settings (`~/.cursor/mcp.json` or project config):

```json
{
  "mcpServers": {
    "arkboard": {
      "command": "python3",
      "args": [
        "/Users/dilipreddy/Origin Ark Studio/arkboard/mcp/server.py"
      ]
    }
  }
}
```

Keep the Arkboard app running — the bridge proxies to `http://127.0.0.1:7420/mcp`.

### Settings UI

**Arkboard → Settings** shows MCP URL, REST base, and database path.

## Data location

```
~/Library/Application Support/Arkboard/arkboard.sqlite
```

## Architecture

```
ArkboardApp
  AppStore (Observable, single write path + activity log)
  GRDB DatabasePool
  MCPServer (NWListener → 127.0.0.1:7420)
  Views: Sidebar · Portfolio · Activity · List · Board · Detail · QuickAdd
```

## License

MIT

## Repo

https://github.com/diliprt/arkboard
