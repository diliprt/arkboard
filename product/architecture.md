# Architecture

Arkboard is one macOS app process holding four things: a SwiftUI window, a SQLite database, an HTTP server bound to loopback, and a reader for `product/` folders on disk. Nothing else runs. There is no daemon, no menu bar agent, no cloud.

```
Arkboard.app  (SwiftUI App, @MainActor)
│
├── AppStore              @Observable facade — the only write path
│   └── ValueObservation  GRDB → @Observable arrays → views
│
├── AppDatabase           GRDB DatabasePool
│   └── ~/Library/Application Support/Arkboard/studio.sqlite
│
├── StudioServer          NWListener on 127.0.0.1:7420
│   ├── /health, /api/*   plain REST
│   └── /mcp              JSON-RPC 2.0, tools/list + tools/call
│
└── DocumentLibrary       reads product/ from disk (or GitHub), never writes
```

## The split that defines everything

Two stores, and knowing which is which prevents every architectural mistake this app can make.

| | `product/` in Git | `studio.sqlite` |
| --- | --- | --- |
| Holds | what the project is meant to be | what has happened to it |
| Written by | a human or agent editing files and committing | the app, through the API |
| Read by | the four document tabs, Monitor's questions | Issues, Timeline, Activity, Monitor's health lanes |
| Lifetime | forever, in history, reviewable | working state of one machine |

The database never stores a copy of a document. Not a cached body, not an excerpt, not a summary. If a document's text appears in a SQL column, something has gone wrong.

## Where each screen gets its data

- **Monitor** joins both: open questions parsed out of `product/`, and capability health plus server status out of SQLite. It is the only screen that mixes them.
- **Project home** is documents on top, database at the bottom. The Design, Architecture, Mockups, and Decisions tabs read `product/` and nothing else. The Issues and Timeline tabs read SQLite and nothing else.
- **Issues, Activity, Portfolio** are database-only, except that Portfolio counts which documents exist.

## Data model

Ten tables, four migrations (`v1`, `v2-project-icon`, `v3-project-pinned`, `v4-activity-metadata`), no legacy. Identifiers are `UUID().uuidString` unless stated. Dates are stored as GRDB `DATETIME`. Existing databases pick up `pinned` in `v3-project-pinned`, default true, and `activity.metadata` in `v4-activity-metadata`, default `{}`.

### Enumerations

| Enum | Values | Notes |
| --- | --- | --- |
| `IssueStatus` | `backlog`, `todo`, `in_progress`, `done`, `canceled` | agent-facing only; humans see Queued / Underway / Done |
| `IssuePriority` | `none`, `low`, `medium`, `high`, `urgent` | agent-facing only; never rendered in the human UI |
| `MilestoneStatus` | `planned`, `in_progress`, `done`, `missed` | |
| `CapabilityState` | `not_started`, `building`, `built` | "is it being implemented" |
| `CapabilityHealth` | `unknown`, `working`, `not_working` | "does it work" |
| `ActivityKind` | `note`, `comment`, `mention`, `handoff`, `system` | drives how a row renders |
| `ActivityAction` | `created_project`, `created_issue`, `updated_issue`, `archived_issue`, `restored_issue`, `commented`, `noted`, `created_milestone`, `updated_milestone`, `created_capability`, `updated_capability` | machine verb |

### Schema

```sql
CREATE TABLE workspace (
  id        TEXT PRIMARY KEY,
  name      TEXT NOT NULL,
  createdAt DATETIME NOT NULL
);

CREATE TABLE project (
  id                TEXT PRIMARY KEY,
  key               TEXT NOT NULL UNIQUE,          -- ARK, 2–6 chars, A–Z0–9
  name              TEXT NOT NULL,
  color             TEXT NOT NULL DEFAULT '#5A62D6',
  icon              TEXT NOT NULL DEFAULT 'circle.fill',  -- SF Symbol; Arkboard is square.3.layers.3d
  summary           TEXT NOT NULL DEFAULT '',      -- one line, only used before product/ loads
  repoPath          TEXT,                          -- absolute path to the local checkout
  githubRepo        TEXT,                          -- owner/name, for remote product/ reads
  issueCounter      INTEGER NOT NULL DEFAULT 0,
  capabilityCounter INTEGER NOT NULL DEFAULT 0,
  sortOrder         DOUBLE NOT NULL DEFAULT 0,
  pinned            INTEGER NOT NULL DEFAULT 1,    -- sidebar pin; existing rows start pinned
  createdAt         DATETIME NOT NULL
);

CREATE TABLE issue (
  id           TEXT PRIMARY KEY,
  identifier   TEXT NOT NULL UNIQUE,               -- ARK-14
  projectId    TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  bodyMarkdown TEXT NOT NULL DEFAULT '',
  status       TEXT NOT NULL DEFAULT 'backlog',
  priority     TEXT NOT NULL DEFAULT 'none',
  assignee     TEXT,
  sortOrder    DOUBLE NOT NULL DEFAULT 0,
  createdAt    DATETIME NOT NULL,
  updatedAt    DATETIME NOT NULL,
  completedAt  DATETIME,                           -- set when status becomes done, cleared when it leaves
  archivedAt   DATETIME                            -- soft delete
);
CREATE INDEX issue_project  ON issue(projectId);
CREATE INDEX issue_status   ON issue(status);
CREATE INDEX issue_archived ON issue(archivedAt);

CREATE TABLE label (
  id    TEXT PRIMARY KEY,
  name  TEXT NOT NULL UNIQUE,                      -- stored lowercase
  color TEXT NOT NULL
);

CREATE TABLE issue_label (
  issueId TEXT NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
  labelId TEXT NOT NULL REFERENCES label(id) ON DELETE CASCADE,
  PRIMARY KEY (issueId, labelId)
);

CREATE TABLE comment (
  id           TEXT PRIMARY KEY,
  issueId      TEXT NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
  bodyMarkdown TEXT NOT NULL,
  author       TEXT NOT NULL,
  createdAt    DATETIME NOT NULL
);
CREATE INDEX comment_issue ON comment(issueId);

CREATE TABLE milestone (
  id                      TEXT PRIMARY KEY,
  projectId               TEXT REFERENCES project(id) ON DELETE SET NULL,  -- NULL = studio-wide
  title                   TEXT NOT NULL,
  bodyMarkdown            TEXT NOT NULL DEFAULT '',
  targetDate              DATETIME NOT NULL,
  status                  TEXT NOT NULL DEFAULT 'planned',
  relatedIssueIdentifiers TEXT NOT NULL DEFAULT '[]',                      -- JSON array of strings
  createdAt               DATETIME NOT NULL,
  updatedAt               DATETIME NOT NULL
);
CREATE INDEX milestone_target ON milestone(targetDate);

CREATE TABLE capability (
  id                     TEXT PRIMARY KEY,
  identifier             TEXT NOT NULL UNIQUE,     -- ARK-C3
  projectId              TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
  title                  TEXT NOT NULL,
  note                   TEXT NOT NULL DEFAULT '', -- one line, 280 chars max, not a document
  state                  TEXT NOT NULL DEFAULT 'not_started',
  health                 TEXT NOT NULL DEFAULT 'unknown',
  docPath                TEXT,                     -- product/design.md
  docAnchor              TEXT,                     -- heading slug within that document
  linkedIssueIdentifiers TEXT NOT NULL DEFAULT '[]',
  sortOrder              DOUBLE NOT NULL DEFAULT 0,
  checkedAt              DATETIME,                 -- last time health was written
  createdAt              DATETIME NOT NULL,
  updatedAt              DATETIME NOT NULL
);
CREATE INDEX capability_project ON capability(projectId);
CREATE INDEX capability_health  ON capability(health);

CREATE TABLE activity (
  id           TEXT PRIMARY KEY,
  createdAt    DATETIME NOT NULL,
  actor        TEXT NOT NULL,
  kind         TEXT NOT NULL,
  action       TEXT NOT NULL,
  body         TEXT NOT NULL,                      -- the message a person reads
  targetActors TEXT NOT NULL DEFAULT '[]',         -- JSON array, from @mentions
  metadata     TEXT NOT NULL DEFAULT '{}',         -- JSON object History does not print
  projectId    TEXT REFERENCES project(id)    ON DELETE SET NULL,
  issueId      TEXT REFERENCES issue(id)      ON DELETE SET NULL,
  capabilityId TEXT REFERENCES capability(id) ON DELETE SET NULL,
  milestoneId  TEXT REFERENCES milestone(id)  ON DELETE SET NULL
);
CREATE INDEX activity_created ON activity(createdAt);
CREATE INDEX activity_project ON activity(projectId);
```

`PRAGMA foreign_keys = ON` on every connection.

### Notes on the shape

**Capabilities, not requirements.** The old build had a `requirement` table that slowly turned into a second document store and then took over Monitor. A capability is deliberately thinner: a title, a one-line note capped at 280 characters, and two independent signals — is it built, does it work. It exists to answer Monitor's second question and for no other reason. The moment a capability wants a body, that body belongs in `product/design.md`, and the capability should point at it with `docPath` and `docAnchor`.

**Activity is the message log.** A comment on an issue writes both a `comment` row and an `activity` row; a studio note writes only an `activity` row with `kind = note`. `body` is what a person reads. A Chief of Staff handoff keeps selection and page focus in `metadata` so History can print the comment alone. `@mentions` are parsed out of the body into `targetActors`, and if the body contains "handoff", "hand off", or "handing off", the kind becomes `handoff`. All four foreign keys are real, with `ON DELETE SET NULL`, so history survives a deletion instead of dangling.

**Identifiers.** `ARK-14` and `ARK-C3` come from `issueCounter` and `capabilityCounter` on the project row, incremented and consumed inside the same GRDB write transaction as the insert. The `UNIQUE` constraint on `identifier` is the backstop. This is safe for one process; two processes on one database file is not a supported configuration.

**Soft delete.** Issues archive by setting `archivedAt`. Nothing in the app hard-deletes an issue. Lists hide archived rows unless explicitly asked, restore clears the column, and the archive action offers a ten-second undo in the UI.

**No GitHub issue sync.** The previous build carried four MCP tools and three columns for mirroring issues into GitHub. It is cut. GitHub appears in exactly one place: reading a remote repository's `product/` folder when a project has `githubRepo` set and no local checkout.

## AppStore

`AppStore` is `@MainActor @Observable`. Views read its arrays; nothing else touches the database.

**Reads** are `ValueObservation` on each table, started once, delivering onto the main actor and assigning to observable properties. Views never query. A mutation from an MCP call updates the UI through the same observation as a mutation from a button — there is no reload-after-write path and no manual refresh, which is what kept the old build's UI and database from drifting.

**Writes** go through one function:

```swift
@discardableResult
func mutate<T>(
    actor: String,
    _ body: (Database) throws -> (value: T, log: ActivityDraft?)
) throws -> T
```

It opens a write transaction, runs the body, appends the activity row from the returned draft inside the same transaction, and commits. Actor is required at the call site — there is no way to write without saying who did it. The UI passes `"Riyu"`. The server passes whatever the caller sent, defaulting to `"Agent"`.

Validation lives with the write path, not in the server, so REST, MCP, and the UI cannot disagree:

- Titles collapse runs of whitespace and newlines to single spaces; empty after trimming is an error.
- Comment and note bodies are trimmed; empty is an error.
- Unknown `status`, `priority`, `state`, `health`, or milestone `status` is rejected before anything is written; a rejected field does not partially apply the rest of the update.
- Labels are trimmed, lowercased, and deduplicated; an update replaces the full set.
- `relatedIssueIdentifiers` and `linkedIssueIdentifiers` must match `^[A-Z][A-Z0-9]{1,5}-(C)?\d+$` and must resolve to rows that exist and are not archived.
- Dates accept ISO 8601 with or without fractional seconds, or bare `yyyy-MM-dd`, which is stored as noon UTC. Anything else is rejected.
- Project keys are uppercased, stripped to `A–Z0–9`, and must be 2 to 6 characters.

## StudioServer

`NWListener` over TCP with `requiredInterfaceType = .loopback`, bound to `127.0.0.1:7420`. Loopback is enforced at the listener, not checked per request.

**Port 7420 is not negotiable.** Agents hard-code it. If the port is taken, the server does not silently pick another one — it stays down, sets a failure reason, and Monitor and Settings both show that the studio API is offline and why.

HTTP/1.1, `Content-Length` required on bodies, 1 MB request cap, one response per request. `OPTIONS` returns 200 and `Access-Control-Allow-Origin: *` so a local tool in a browser tab can talk to it.

### REST

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | liveness and version |
| GET | `/api/projects` | list projects |
| POST | `/api/projects` | create a project |
| PATCH | `/api/projects/{idOrKey}` | update a project (`pinned`) |
| GET | `/api/issues` | list, with `projectKey`, `status`, `query`, `includeArchived` |
| POST | `/api/issues` | create an issue |
| GET | `/api/issues/{idOrIdentifier}` | one issue with comments |
| PATCH | `/api/issues/{idOrIdentifier}` | update |
| DELETE | `/api/issues/{idOrIdentifier}` | archive |
| POST | `/api/issues/{idOrIdentifier}/restore` | unarchive |
| POST | `/api/issues/{idOrIdentifier}/comments` | comment |
| GET | `/api/activity` | recent activity, `limit` and `projectKey` |
| POST | `/api/notes` | post a studio or project note |
| GET | `/api/milestones` | list milestones |
| POST | `/api/milestones` | create a milestone |
| GET | `/api/capabilities` | list capabilities |
| POST | `/api/capabilities` | create a capability |
| GET | `/api/documents` | list documents in a project's `product/` |
| GET | `/api/documents/{path}` | read one document's raw markdown |

`/health` returns:

```json
{ "name": "Arkboard", "version": "2.0.0", "mcp": "/mcp", "api": "/api", "database": "ok", "projects": 1 }
```

Errors are `{"error": "..."}` with 400 for validation, 404 for a missing row, 503 if the store is not ready.

### MCP

`POST /mcp` speaks JSON-RPC 2.0: `initialize`, `ping`, `tools/list`, `tools/call`. `GET /mcp` returns a self-description with the tool names. Notifications without an `id` get a 202 and no body. The full tool catalogue and every contract is in [mcp.md](mcp.md); do not restate it here, because two copies will disagree.

A stdio bridge at `mcp/bridge.py` lets editors that only speak stdio reach the same endpoint. It forwards frames to `http://127.0.0.1:7420/mcp` and returns a clear error when the app is not running.

## DocumentLibrary

An actor that turns a project into a tree of readable documents. It reads. It never writes to `product/`, and it never writes to SQLite.

### Finding the folder

In order, stopping at the first that yields a `product/` directory:

1. `project.repoPath` from the database, if the path still exists.
2. The `ARKBOARD_REPO_ROOT` environment variable, for development runs.
3. Walking up from `Bundle.main.bundleURL`, at most ten levels, looking for a directory that contains both `.git` and `product/`. This is what makes a Debug build launched from the repo find its own documents.
4. A folder the user picked in Settings, stored against the project.
5. `githubRepo`, fetched through the `gh` CLI if it is installed and authenticated.

No path to any developer's home directory appears in the source. That was a real bug in the previous build and it made the app work on exactly one machine.

### Reading

Everything under `product/` is enumerated recursively. `.md` and `.txt` load as text; `.png`, `.jpg`, `.jpeg`, `.gif`, and `.webp` load as image data; anything else is ignored, as is any path under `product/baseline/` or `product/blueprint/`.

Results are cached per project in memory. The cache is reloaded when the app becomes active, when the user hits Refresh in the project header, and — if the optional file watcher is built — when anything under the folder changes on disk. A refresh must not replace a successful bundle with an empty one (a later `becomeActive` or a race before `projects` is assigned). The project home and `list_documents` share one publish path (`ensureDocuments` → replace `documentBundles`) so a successful library read is visible in the window. Contents visibility does not affect loading. `arkboard.contentsVisible` is written on toggle and read at launch. Saving `design.md` in an editor and seeing the Design tab update without touching the app is the workflow this exists for.

Load failures are not swallowed. A project whose documents failed to load says so in the project header and contributes a row to Monitor's broken lane. If a later refresh cannot find `product/` again, the last successful bundle stays on screen.

### Routing a file to a tab

Deterministic, first match wins:

1. `product/README.md`, `product/overview.md`, or `product/OVERVIEW.md` → Overview.
2. A file under `product/design/`, `product/architecture/`, `product/mockups/`, `product/decisions/`, or `product/questions/` → that tab.
3. Exact filename stem `design`, `architecture`, `mockups`, `decisions`, or `questions` → that tab.
4. Filename stem containing a keyword, checked in this order:
   - Design — `design`, `ui`, `ux`, `visual`, `brand`, `spec`
   - Architecture — `arch`, `api`, `mcp`, `data`, `schema`, `engine`, `infra`
   - Decisions — `decision`, `question`, `rfc`, `adr`
   - Mockups — `mockup`, `frame`, `wireframe`, `screen`, `flow`
5. Any image not referenced inline by a document → Mockups.
6. Anything left over → listed under "More documents" in the Overview header.

Within a tab, the primary document is the one whose stem matches the tab exactly, otherwise the alphabetically first. Additional documents appear as a rail above the content. This is why the design pack lands where it does: `ui-spec.md` reads as Design, `mcp.md` reads as Architecture, and nothing in the folder is invisible.

### Open questions

Monitor's questions come from the Decisions documents of every project, parsed with one rule: a heading at level 2 or 3 is an **open question** if its text starts with `Open` or ends with `?`, and a **locked decision** if it starts with `Locked` or `Decided`. The question's body is the markdown up to the next heading of the same or higher level. Each question carries its project, document path, and heading slug, so clicking it opens that project's Decisions tab scrolled to that heading.

This is why `decisions.md` is written the way it is. The convention is the parser.

## Settings and persistence

`UserDefaults`, one key per setting, all read at launch and applied at the root of the view tree.

| Key | Type | Default |
| --- | --- | --- |
| `arkboard.appearance` | `light` / `dark` / `system` | `light` |
| `arkboard.fontSize` | `12` / `13` / `14` / `16` | `13` |
| `arkboard.fontFamily` | face identifier | `system` |
| `arkboard.sidebarSelection` | `portfolio` / `timeline` / `onboarding` / `project:<id>` | `portfolio` |
| `arkboard.serverPort` | Int, informational | `7420` |
| `arkboard.contentsVisible` | Bool | `true` |

## Seed

On an empty database, and only then: a workspace named **Origin Ark**, and one project — **Arkboard**, key `ARK`, colour `#5A62D6`, icon `square.3.layers.3d`, `repoPath` set to the resolved repository root, `githubRepo` set to `diliprt/arkboard`. Then a handful of capabilities describing the app's own day-one surface, one milestone, and a single activity row welcoming the studio. Existing databases pick up `icon` in `v2-project-icon` and receive a distinct mark per project so the portfolio is never a row of identical dots. They pick up `pinned` in `v3-project-pinned`, default true, so Arkboard does not vanish from the sidebar. They pick up `activity.metadata` in `v4-activity-metadata`, default `{}`.

Nothing fictional. The previous build seeded a demo project and a fake three-bot conversation, and the first thing anyone had to do was work out which rows were real. One real project, and everything you see is true.

## Build and run

XcodeGen generates the project; the checked-in `project.yml` is the source of truth.

- Target `Arkboard`, macOS 14.0 deployment, bundle identifier `studio.originark.arkboard`.
- Swift 5.10, `SWIFT_STRICT_CONCURRENCY: minimal`. The store and views are `@MainActor`; the listener and the document library are the only things off it.
- One dependency: GRDB.swift, `from: 7.4.0`.
- Entitlements: sandbox off, network server and client on, user-selected files read-write. This is a local developer tool that binds a port and reads arbitrary repositories; sandboxing it would mean shipping a folder-picker dance for every project.
- Ad-hoc signing, hardened runtime off. Nothing here is distributed.

```bash
./scripts/run.sh    # xcodegen if needed → xcodebuild Debug → open Arkboard.app
./scripts/smoke.sh  # end-to-end proof against a running app
```

Launch the `.app`, not the binary inside it, or the app will run without its bundle.

### What the smoke script must prove

Against a running app, with `curl` and `jq`, exiting non-zero on the first failure:

1. `/health` answers and reports the database as ok.
2. `tools/list` returns the full catalogue from [mcp.md](mcp.md).
3. `create_issue` with `actor: "Ops"` returns an identifier, and the matching activity row names Ops.
4. `update_issue` to `done` sets `completedAt`; moving it back clears it.
5. `add_comment` with two `@mentions` produces exactly one activity row carrying both targets.
6. `delete_issue` hides the issue from `list_issues`, `restore_issue` brings it back, and the activity history still names it.
7. `create_milestone` with an unknown related identifier is rejected; a valid one succeeds.
8. `create_capability` then `update_capability` to `not_working` puts it in `list_capabilities` filtered by health.
9. Empty titles, empty comments, unknown status values, and unparseable dates each return an error rather than writing.
10. `list_documents` for `ARK` returns this design pack, and `read_document` returns markdown that starts with `# Architecture`.

The script cleans up what it creates.

## Source layout

```
Sources/Arkboard/
  ArkboardApp.swift              App, Scenes, commands, appearance
  Model/
    Entities.swift               Project, Issue, Comment, Milestone, Capability, Activity
    Enums.swift                  status, priority, state, health, kind, action
    ProjectMark.swift            persisted SF Symbol + colour, product/ image names
    HumanVocabulary.swift        status → Queued / Underway / Done
  Data/
    AppDatabase.swift            DatabasePool, migrations v1 and v2-project-icon, path
    AppStore.swift               @Observable, ValueObservation, mutate()
    Validation.swift             titles, dates, labels, identifiers
    Seed.swift                   first-run seed
  Documents/
    DocumentLibrary.swift        actor, discovery, cache, refresh
    DocumentRouting.swift        file → tab rules
    MarkdownParser.swift         text → [Block]
    QuestionParser.swift         Decisions → open questions
  Server/
    StudioServer.swift           NWListener, HTTP framing
    RESTRoutes.swift
    MCPRoutes.swift              JSON-RPC envelope
    ToolCatalogue.swift          one entry per tool, schema + handler
  UI/
    Theme/                       Hue, Section, Typography, Metrics, modifiers
    Markdown/                    MarkdownView, ContentsOutline, CodeBlock, TableView
    Shell/                       RootView, Sidebar, ScreenHeader, NoteComposer, Onboarding
    Monitor/  Issues/  Activity/  Portfolio/  Project/  Settings/
  Resources/
    Assets.xcassets              AppIcon
```

Every file under `UI/` should be readable in one sitting. If a view file passes roughly 300 lines, it is doing two jobs.
