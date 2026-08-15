# The agent API

Arkboard exposes one small API on loopback. Agents use it to file work, report what is broken, read the product documents, and talk to the studio. Twenty tools, all of them boring on purpose.

Base URL is `http://127.0.0.1:7420` and it is not configurable. The listener refuses anything that is not loopback.

## Connecting

**MCP over HTTP** — `POST /mcp` speaking JSON-RPC 2.0. Supported methods are `initialize`, `ping`, `tools/list`, and `tools/call`. A `GET /mcp` returns a short self-description with the tool names.

```bash
curl -s -X POST http://127.0.0.1:7420/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq '.result.tools[].name'
```

**MCP over stdio** — for editors that only speak stdio, `mcp/bridge.py` forwards frames to the same endpoint.

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

**REST** — the same operations at `/api/*` for shell scripts and anything that would rather not speak JSON-RPC. The route table is in [architecture.md](architecture.md).

The app must be running. There is no headless mode; the database belongs to the app process.

## Envelopes

A call:

```json
{"jsonrpc":"2.0","id":7,"method":"tools/call",
 "params":{"name":"create_issue","arguments":{"projectKey":"ARK","title":"Outline bar drops H3 headings","actor":"Cursor"}}}
```

A result carries the payload twice — once as pretty JSON text for models that read `content`, once structured for clients that parse:

```json
{"jsonrpc":"2.0","id":7,"result":{
  "content":[{"type":"text","text":"{ ... }"}],
  "structuredContent":{ "...": "the payload described below" }}}
```

An error is HTTP 200 with a JSON-RPC error body. `-32700` for unparseable input, `-32601` for an unknown method or tool, `-32000` for anything the app rejected, with a message written for a human to read.

```json
{"jsonrpc":"2.0","id":7,"error":{"code":-32000,"message":"Unknown status 'started'. Use backlog, todo, in_progress, done, or canceled."}}
```

## Actor

Every mutating tool takes an optional `actor` string. It defaults to `"Agent"`, and it lands on the activity row and, for comments, on the authorship.

Use your own name. `Cursor`, `Grok`, `Ops`, `Product` — whatever the studio will recognise in the Activity feed. `Riyu` is reserved for the human sitting at the app; do not send it.

Mentions in a comment or note body are parsed with `@Name` and recorded as targets, so `@Ops please retry the build` renders as a handoff to Ops. A body containing "handoff", "hand off", or "handing off" is recorded as a handoff rather than a plain mention.

## Objects

Every date is ISO 8601 with fractional seconds. Absent values are `null`, never omitted.

**Project** — `id`, `key`, `name`, `color`, `icon`, `summary`, `repoPath`, `githubRepo`, `pinned`, `openIssueCount`, `createdAt`

**Issue** — `id`, `identifier`, `projectId`, `projectKey`, `title`, `body`, `status`, `priority`, `assignee`, `labels[]`, `createdAt`, `updatedAt`, `completedAt`, `archivedAt`

**Comment** — `id`, `issueId`, `issueIdentifier`, `body`, `author`, `createdAt`

**Activity** — `id`, `createdAt`, `actor`, `targetActors[]`, `kind`, `action`, `body`, `projectId`, `projectKey`, `issueId`, `issueIdentifier`, `capabilityId`, `capabilityIdentifier`, `milestoneId`

**Milestone** — `id`, `projectId`, `projectKey`, `title`, `body`, `targetDate`, `status`, `relatedIssueIdentifiers[]`, `dependsOn[]`, `createdAt`, `updatedAt`

**Capability** — `id`, `identifier`, `projectId`, `projectKey`, `title`, `note`, `state`, `health`, `docPath`, `docAnchor`, `linkedIssueIdentifiers[]`, `checkedAt`, `createdAt`, `updatedAt`

**Document** — `path`, `tab`, `title`, `bytes`, `isImage`, `modifiedAt`

## Projects

### `list_projects`

Every project. No parameters.

Returns `{ "projects": [Project] }`.

### `create_project`

| Parameter | Type | Required | Default |
| --- | --- | --- | --- |
| `key` | string | yes | — |
| `name` | string | yes | — |
| `color` | string | no | assigned from the ramp when omitted |
| `icon` | string | no | SF Symbol; assigned a distinct unused mark when omitted |
| `summary` | string | no | `""` |
| `repoPath` | string | no | `null` |
| `githubRepo` | string | no | `null` |
| `pinned` | boolean | no | `true` |
| `actor` | string | no | `Agent` |

`key` is uppercased and stripped to `A–Z0–9`; it must end up 2 to 6 characters and must be unique.

Returns the `Project`.

### `update_project`

| Parameter | Type | Required | Default |
| --- | --- | --- | --- |
| `id` or `key` | string | yes | — |
| `pinned` | boolean | no | unchanged |
| `actor` | string | no | `Agent` |

Returns the `Project`. Agents use this to pin or unpin. The human UI writes the same field from the Portfolio card and the sidebar context menu.

## Documents

Read-only. `product/` is written by editing files in the repository and committing them, and no tool here will change that.

### `list_documents`

| Parameter | Type | Required | Notes |
| --- | --- | --- | --- |
| `projectKey` | string | yes | |
| `tab` | string | no | `design`, `architecture`, `mockups`, `decisions`, `overview` |

Returns `{ "source": "local", "root": "/…/arkboard/product", "documents": [Document] }`. `source` is `local`, `github`, or `none`.

### `read_document`

| Parameter | Type | Required | Notes |
| --- | --- | --- | --- |
| `projectKey` | string | yes | |
| `path` | string | yes | repo-relative, must start with `product/` |

Returns `{ "path": …, "tab": …, "markdown": …, "headings": [{ "level": 2, "title": …, "anchor": … }] }`.

Paths are resolved inside the project's `product/` folder and rejected if they escape it.

## Issues

### `list_issues`

| Parameter | Type | Default | Notes |
| --- | --- | --- | --- |
| `projectKey` | string | — | |
| `status` | string | — | one of the five |
| `query` | string | — | substring over identifier, title, body |
| `includeArchived` | boolean | `false` | |
| `limit` | integer | `200` | 1–500 |

Returns `{ "issues": [Issue] }`, newest update first. Archived issues are hidden unless asked for.

### `get_issue`

Takes `id` or `identifier`. Returns the `Issue` plus `comments` and `activity`, both chronological — the whole thread in one call.

### `create_issue`

| Parameter | Type | Required | Default |
| --- | --- | --- | --- |
| `title` | string | yes | — |
| `projectKey` or `projectId` | string | one of them | — |
| `body` | string | no | `""` |
| `status` | string | no | `backlog` |
| `priority` | string | no | `none` |
| `labels` | string[] | no | `[]` |
| `assignee` | string | no | `null` |
| `actor` | string | no | `Agent` |

Titles collapse whitespace and cannot be empty. Labels are lowercased and deduplicated. Returns the `Issue`.

### `update_issue`

Takes `id` or `identifier`, plus any of `title`, `body`, `status`, `priority`, `labels`, `assignee`, `actor`. Omitted fields are untouched; `labels` replaces the whole set.

Moving to `done` stamps `completedAt`; moving away clears it. An unknown `status` or `priority` rejects the entire call — no partial writes.

Returns the updated `Issue`.

### `delete_issue`

Takes `id` or `identifier` and optional `actor`. Soft delete: sets `archivedAt`, keeps the row and its history. Returns the `Issue`.

### `restore_issue`

The inverse. Returns the `Issue`.

## Conversation

### `add_comment`

| Parameter | Type | Required |
| --- | --- | --- |
| `identifier` or `issueId` | string | yes |
| `body` | string | yes |
| `actor` | string | no |

Writes a comment and one activity row — one row even when the body mentions several people. Returns the `Comment`.

### `post_note`

Says something in Activity without attaching it to an issue. This is how an agent answers Riyu.

| Parameter | Type | Required | Notes |
| --- | --- | --- | --- |
| `body` | string | yes | |
| `projectKey` | string | no | omit for a studio-wide note |
| `actor` | string | no | |

Returns the `Activity`. Handoff rows from the board include a `metadata` object (selected text, page, tab, document, heading) that History does not print. `body` is the comment the human typed.

## Activity

### `list_activity`

| Parameter | Type | Default |
| --- | --- | --- |
| `limit` | integer | `50`, capped at 500 |
| `projectKey` | string | — |
| `kind` | string | — |
| `since` | string | — |

Returns `{ "activities": [Activity] }`, newest first. Poll this to see what Riyu asked for.

## Milestones

### `list_milestones`

Optional `projectKey` — pass `studio` for milestones with no project — and optional `status`. Returns `{ "milestones": [Milestone] }` by target date.

### `create_milestone`

| Parameter | Type | Required | Default |
| --- | --- | --- | --- |
| `title` | string | yes | — |
| `body` | string | no | `""` |
| `targetDate` | string | no | seven days out |
| `status` | string | no | `planned` |
| `projectKey` | string | no | studio-wide |
| `relatedIssueIdentifiers` | string[] | no | `[]` |
| `dependsOn` | string[] | no | `[]` |
| `actor` | string | no | `Agent` |

`targetDate` accepts ISO 8601 or `yyyy-MM-dd`, which is stored at noon UTC. Related identifiers must name issues that exist and are not archived.

`dependsOn` holds the ids of milestones that must land first. Ids are trimmed and deduplicated. Every id must name a milestone that exists, or the whole call is rejected with `Unknown milestone dependency '<id>'.`

### `update_milestone`

Takes `id` plus any create field. Returns the `Milestone`.

Writing `dependsOn` replaces the whole predecessor list. A milestone may not depend on itself (`A milestone cannot depend on itself.`) and the graph must stay acyclic (`Milestone dependencies cannot form a cycle.`). Both are checked before anything is written.

Dependencies are how agents express order. The human Timeline draws them as links between milestone bars and offers no way to edit them, so this API is the only writer.

```bash
curl -sX PATCH http://127.0.0.1:7420/api/milestones/<id> \
  -H 'Content-Type: application/json' \
  -d '{"dependsOn":["<predecessor-id>"],"actor":"Product"}'
```

## Capabilities

A capability answers two questions about one piece of the product: is it built, and does it work. It is not a spec — the spec is in `product/`. Keep `note` to a single line under 280 characters, and use `docPath` and `docAnchor` to point at the heading that actually describes it.

`state` is `not_started`, `building`, or `built`. `health` is `unknown`, `working`, or `not_working`.

### `list_capabilities`

Optional `projectKey`, `state`, `health`. Returns `{ "capabilities": [Capability] }`.

### `create_capability`

| Parameter | Type | Required | Default |
| --- | --- | --- | --- |
| `title` | string | yes | — |
| `projectKey` or `projectId` | string | one of them | — |
| `note` | string | no | `""` |
| `state` | string | no | `not_started` |
| `health` | string | no | `unknown` |
| `docPath` | string | no | `null` |
| `docAnchor` | string | no | `null` |
| `linkedIssueIdentifiers` | string[] | no | `[]` |
| `actor` | string | no | `Agent` |

### `update_capability`

Takes `id` or `identifier` plus any of the above. Writing `health` also stamps `checkedAt`, which is what Monitor shows as `checked 20m ago`.

Setting `health` to `not_working` puts the capability on Monitor immediately. That is the loudest thing an agent can do in this app, so make the note specific: what you ran, and what happened.

## Etiquette

The API is small enough that the manners matter more than the surface.

1. **Say who you are.** Send `actor` on every mutation. An unattributed row is a row nobody can follow up on.
2. **Read before you write.** `list_documents` and `read_document` tell you what the project is supposed to be. Filing work against the design pack beats filing work against a guess.
3. **Report health after you check it.** If you ran the smoke script, update the capabilities it covers. Monitor is only as honest as the last check written to it.
4. **Answer in Activity.** When Riyu posts a note, `post_note` back. The feed is a conversation, not a log.
5. **Never write documents through the API.** Edit `product/` in the repository and commit. The app reads that folder on the next refresh.
6. **One issue per real thing.** Issues are for tracking work, not for storing notes. A thought goes in a note; a decision goes in `product/decisions.md`.

## Not in this API

Cut deliberately, and worth knowing about before someone tries to add them back:

- **GitHub issue sync.** The previous build could mirror issues into GitHub through four tools and three columns. It is gone. GitHub is used for exactly one thing: reading a remote repository's `product/` folder.
- **Document writes.** No `write_document`, no `create_requirement` that quietly becomes a document store.
- **Search as its own tool.** `list_issues` takes a `query`.
- **Thread listing as its own tool.** `get_issue` returns the thread.
- **Bulk operations, webhooks, subscriptions.** Poll `list_activity`.
