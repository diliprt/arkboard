# Arkboard

**Local Linear-style issue tracker for macOS** — SwiftUI + SQLite (GRDB) + agent MCP on localhost.

Built for Origin Ark Studio so product direction lives in a real tracker, not chat scrollback. Agents (Cursor / Grok Bot) can list, create, and update issues via a local API.

## Features (v1)

- Projects + Issues (status, priority, labels, comments)
- **List** and **Board** (kanban by status) views
- Quick add with **⌘N**
- Local SQLite in Application Support
- Local HTTP server on **`127.0.0.1:7420`**
  - REST: `/api/projects`, `/api/issues`
  - MCP-shaped JSON-RPC: `POST /mcp` (`tools/list`, `tools/call`)
- Stdio MCP bridge: `mcp/server.py` for Cursor

### Statuses
`backlog` · `todo` · `in_progress` · `done` · `canceled`

### Priorities
`none` · `low` · `medium` · `high` · `urgent`

## Requirements

- macOS 14+
- Xcode 15+ (Xcode 26 tested)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Optional: Python 3 for the stdio MCP bridge

## Build & run

```bash
cd "/Users/dilipreddy/Origin Ark Studio/arkboard"
xcodegen generate
xcodebuild -scheme Arkboard -configuration Debug \
  -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' build
open build/DerivedData/Build/Products/Debug/Arkboard.app
```

Or open the generated `Arkboard.xcodeproj` in Xcode and press Run.

On first launch the app seeds demo projects (**ARK**, **OPS**) and sample issues, then starts MCP on port **7420**.

## REST API (curl)

App must be running.

```bash
# Health
curl -s http://127.0.0.1:7420/health | jq

# List projects
curl -s http://127.0.0.1:7420/api/projects | jq

# List issues
curl -s 'http://127.0.0.1:7420/api/issues?projectKey=ARK' | jq

# Create issue
curl -s -X POST http://127.0.0.1:7420/api/issues \
  -H 'Content-Type: application/json' \
  -d '{"projectKey":"ARK","title":"From curl","status":"todo","priority":"high","labels":["agent"]}' | jq

# Update issue
curl -s -X PATCH http://127.0.0.1:7420/api/issues/ARK-1 \
  -H 'Content-Type: application/json' \
  -d '{"status":"in_progress"}' | jq
```

## MCP for Cursor / agents

### Option A — HTTP JSON-RPC (app embedded)

While Arkboard is open:

```bash
curl -s -X POST http://127.0.0.1:7420/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq
```

Tools: `list_projects`, `create_project`, `list_issues`, `search_issues`, `get_issue`, `create_issue`, `update_issue`, `add_comment`.

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
  AppStore (Observable, single write path)
  GRDB DatabasePool
  MCPServer (NWListener → 127.0.0.1:7420)
  Views: Sidebar · List · Board · Detail · QuickAdd
```

## License

MIT

## Repo

https://github.com/diliprt/arkboard
