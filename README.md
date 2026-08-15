# Arkboard

Local-first studio board for macOS. Humans read and steer. Agents execute through localhost MCP.

Documents live in Git under `product/`. Events — issues, comments, activity, milestones, capability health — live in a SQLite file on this machine. The app never writes `product/` and never copies document text into the database.

The design pack in [`product/`](product/README.md) is the specification. If a document in that folder reads badly inside the app, the renderer is wrong.

## What you see

Sidebar: **Monitor**, **Issues**, **Activity**, **Portfolio**, then projects.

A project opens as a document home — overview, then Design, Architecture, Mockups, Decisions & questions, Issues, Timeline. The first four tabs render `product/` markdown as a rich preview. Issues are tracking only. Timeline is milestones.

The human UI has no status, priority, or assignee controls, and no New Issue button. Say what you want in the Monitor composer. Agents file it.

## Requirements

- macOS 14+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Optional: Python 3 for the stdio MCP bridge

This repository can be edited on Linux. It cannot be compiled there. There is no `xcodebuild` on Cloud Agent hosts.

## Run (Mac)

```bash
./scripts/run.sh
```

That generates the Xcode project, builds Debug, and opens `Arkboard.app`. Launch the `.app`, not the binary inside it. `ARKBOARD_REPO_ROOT` is set to the repo so a Debug build finds this `product/` folder.

On first launch the app seeds one real project — **Arkboard** (`ARK`) — pointed at this repository. Nothing fictional.

## Smoke (Mac, app running)

```bash
./scripts/smoke.sh
```

Proves `/health`, the nineteen MCP tools, actor attribution, soft-delete, capabilities, validation errors, and that `read_document` returns this design pack.

On Linux, without the app:

```bash
python3 scripts/spec_check.py
```

## Agent API

`http://127.0.0.1:7420` — not configurable. If the port is taken the server stays down and Monitor says so.

- Health: `GET /health`
- REST: `/api/projects`, `/api/issues`, `/api/activity`, `/api/notes`, `/api/milestones`, `/api/capabilities`, `/api/documents`
- MCP: `POST /mcp` (`initialize`, `ping`, `tools/list`, `tools/call`)

Mutating calls take `actor`. Default is `Agent`. Do not send `Riyu`.

Stdio bridge for editors that cannot speak HTTP:

```json
{
  "mcpServers": {
    "arkboard": {
      "command": "python3",
      "args": ["<repo>/mcp/bridge.py"]
    }
  }
}
```

Tool contracts: [`product/mcp.md`](product/mcp.md).

## Data

```
~/Library/Application Support/Arkboard/studio.sqlite
```

## License

MIT
