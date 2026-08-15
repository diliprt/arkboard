# Arkboard

Local-first studio board for macOS. Humans read and steer. Agents execute through localhost MCP.

Documents live in Git under `product/`. Events — issues, comments, activity, milestones, capability health — live in a SQLite file on this machine. The app never writes `product/` and never copies document text into the database.

The design pack in [`product/`](product/README.md) is the specification. If a document in that folder reads badly inside the app, the renderer is wrong.

## What you see

The left sidebar is a portfolio of projects, each with its own brand mark. Click a project to open its document home — overview, then Design, Architecture, Mockups, Decisions & questions, Issues, Timeline. The first four tabs render `product/` markdown as a rich preview. Long documents list headings in the right-hand Contents column. Issues are a project tab only. Timeline is a Gantt: projects as rows, milestones underneath, bars on one time axis, and links between milestones that wait on each other.

The human UI has no status, priority, or assignee controls, and no New Issue button. Say what you want on the project. Agents file it. Monitor and Issues are not left-sidebar rows.

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
python3 scripts/spec_check.py       # design pack, routing, layout, and Timeline rules
./scripts/gantt_check.sh            # compiles and unit-tests the Timeline maths (needs swiftc)
python3 scripts/timeline_preview.py # draws the Timeline Gantt's layout to SVG/PNG
```

`scripts/gantt_check.sh` builds `Sources/Arkboard/UI/Portfolio/TimelineModel.swift` on its own. That file imports Foundation only, so the Gantt's axis, bar, and dependency logic is testable on a Linux host with no Xcode.

`scripts/timeline_preview.py` draws that same geometry — row order, bar spans, dependency links, the Today rule, each scale — so a Timeline change can be looked at before anyone opens Xcode. It is a geometry preview, not a screenshot; sign the finished screen off on a Mac.

## Agent API

`http://127.0.0.1:7420` — not configurable. If the port is taken the server stays down and Settings (and the sidebar footer) say so.

- Health: `GET /health`
- REST: `/api/projects`, `/api/issues`, `/api/activity`, `/api/notes`, `/api/milestones` (`PATCH /api/milestones/{id}` sets `dependsOn`), `/api/capabilities`, `/api/documents`
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
