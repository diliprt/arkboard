# UI specification

Every surface in Arkboard, what it contains, and what it refuses to contain. Colours, sizes, and the type scale come from [design.md](design.md); this document names the screens and the words on them.

Copy in fixed-width in the tables below is literal. Ship those strings.

## The shell

A single window. `NavigationSplitView` with two columns: the project portfolio and the current page. Contents is a trailing pane inside the document column — not a third split column, which collapsed the page to empty white.

- Minimum 1080 × 700, default 1320 × 860, `.windowStyle(.automatic)`, unified toolbar.
- The selected row is restored on launch from `arkboard.sidebarSelection`. Valid values are `portfolio`, `timeline`, `onboarding`, or `project:<id>`. Leftover studio chrome (`monitor`, `issues`, `activity`) is discarded and Portfolio is selected.
- The window title is Portfolio, Timeline, Onboarding, or the current project name; the subtitle is the workspace name.

### Sidebar

232pt wide, `.sidebar` list style, one selection. There is no Studio section. The workspace name lives in the window subtitle, not in this column. No workspace icon, no fake destination.

**Destinations**, in this order:

1. **Portfolio** — a real row. Portfolio is a destination. Selecting it shows the Portfolio page in the document column.
2. **Timeline** — a real row. Timeline is a destination. Selecting it shows the master studio calendar.

A single hairline `Divider` sits between those two destinations and the pinned projects below. Not a section header that says `Projects`.

**Pinned projects** — under that hairline, only projects whose `pinned` flag is true, sorted by `sortOrder` then name. Clicking a pinned row opens that project's document home (Design default). Unpinning removes the row from the sidebar; the project stays on the Portfolio page. Pinning puts it back. Existing projects start pinned so Arkboard does not disappear on first launch.

Each project row: the project's persisted mark (22pt), the name in `body`, and the key in `mono` `caption` trailing, right-aligned and secondary. The mark is that app's brand — an SF Symbol on a 6pt-radius square washed with the project's colour, or an image from `product/icon.png` / `product/mark.png` / `product/logo.png` when one exists. It is never the same blue dot for every project. A context menu on the row offers `Pin` / `Unpin`.

Arkboard's own mark is `square.3.layers.3d` in indigo `#5A62D6`. Other projects get a distinct symbol (and a distinct colour when they would otherwise share indigo).

**Not in this sidebar.** Monitor and Issues are leftover ticket chrome. Issues stay as a tab on the project page. Monitor is not a studio row. Activity is not a row.

**Footer**, pinned, on `.bar`:

- **Onboarding** — a `sparkles` icon, help text `Onboarding`. Not labelled Setup. Not a gear. Clicking it opens the Onboarding page in the document column.
- A 7pt dot and `Agents · :7420` in `caption`. Moss when the server is listening, crimson and `Agents offline` when it is not. Clicking opens Settings to the Agents section.

Create is not in this column.

### Contents

A trailing pane beside the document, 220pt ideal, 180 min, 280 max, user-resizable in that range. A toolbar `sidebar.trailing` toggle collapses and restores it; the choice persists as `arkboard.contentsVisible`. The document column itself is at least 560pt. This is the outline. Do not put it on the left. Do not also pin an `On this page` chip rail — one outline, on the right.

- Header `Contents` in `caption`, secondary.
- One heading per row, indented 12pt per level below `#`, `bodyStrong` for `#`/`##` and `caption` deeper.
- Clicking a heading scrolls the current page to that subsection, landing it at the top, over 0.2s.
- Shown when the current document tab has two or more headings. Otherwise a quiet `This page has no subsections.` in `callout` tertiary. Issues, Timeline, and Mockups without headings use that empty line.

### Screen header

Every studio screen opens the same way, fixed above the scroll:

1. Section symbol at `heading` size in the section hue.
2. Title in `title`.
3. A one-line subtitle in `callout`, secondary.
4. Optional trailing controls.
5. A 1pt divider in the section hue at 22%.

The pane below carries the section wash. Everything under the header lives in exactly one vertical scroll.

## Monitor

Not a sidebar row. The engine — open questions parsed from Decisions, capabilities that are not working — still exists for agents and for the project page. There is no studio Monitor destination in the human chrome.

### Composer

A compact note sheet opened from the project-home header icon (or `⌘N`), not a large box in the project scroll.

- A short field, placeholder `Tell the team…`, `Send` with `⌘↩`.
- **History** of notes for this project from existing Activity. No second store.
- Sending posts an activity note authored by `Riyu`, scoped to the current project, and clears the field.

This is how a human asks for work. There is no issue form anywhere in the app; you say what you want and an agent files it.

### Open questions

Section header `Open questions` in `heading` with a count. One card per question parsed from every project's Decisions documents.

Each card: gold stroke and wash, the question heading in `bodyStrong`, a project chip in the project's colour, then the question body rendered as rich markdown clamped to four lines, then a trailing `chevron.right`. Clicking opens that project's Decisions tab scrolled to the heading.

### Not working

Section header `Not working` with a count. One card per capability whose health is `not_working`, sorted by `checkedAt` descending.

Each card: crimson stroke and wash, the capability title in `bodyStrong`, its identifier in `mono` `caption`, a project chip, the note on one line, `checked 20m ago` in `caption`, and any linked issue identifiers as capsule chips. Clicking opens the linked document heading when the capability has one, otherwise the project home.

### Studio health

A quiet strip at the bottom, `caption`, no card.

- Always: the agent API — `Agents listening on 127.0.0.1:7420` in moss, or `Agents offline — port 7420 is in use` in crimson.
- Only when failing: one line per project whose documents could not be read, naming the project and the reason.

## Issues

A tab on the project page only. There is no studio-wide Issues row in the left sidebar. The engine is unchanged: agents file and update tickets through the API; humans read them here.

Subtitle, when the tab is open: `Tracking only. Agents file and update these.`

Clicking a row opens that issue's detail in a sheet — identifier, title, metadata, body, comments, and the comment composer. Archive with undo still applies. Nothing else.

### List

One scroll, a `LazyVStack` with pinned group headers — never a `List` inside a `ScrollView`. Groups in this order, each shown only when it has rows:

| Group header | Contains |
| --- | --- |
| `Underway` | status `in_progress` |
| `Queued` | status `backlog` and `todo` |
| `Done` | status `done`, completed in the last 14 days, newest first |

Group headers are uppercase `caption` in teal with a count.

A row is one line of identifier in `mono` `caption`, then the title in `body`, then label chips, then the relative updated time trailing in `caption`.

There is no status pill on a row. The group is the status, and that is all the status a human needs.

Right-clicking a row offers `Copy identifier`, `Copy title`, and `Archive`.

### Detail sheet

- Identifier in `mono` `caption`, title in `display`.
- A metadata line: project chip, `filed 3d ago`, `updated 2h ago`, then label chips.
- The issue body as rich markdown.
- `Comments` in `heading`, then each comment: actor chip in the actor's colour, relative time, and the body rendered as rich markdown.
- A comment composer at the bottom, placeholder `Add a comment…`, `⌘↩` to post, authored by `Riyu`.
- One toolbar action: `Archive`, which soft-deletes and raises the undo toast.

Nothing else. No status control, no priority control, no assignee control, no label editor, no estimate, no linked-issue picker.

### Undo toast

Floating at the bottom of the window, `regularMaterial`, radius 14, the one shadow. Text `Archived ARK-14`, an `Undo` button, and a dismiss `xmark`. Auto-dismisses after ten seconds.

## Activity

Subtitle: `Everyone talking — agents and you.`

Fixed header with a segmented filter: `People & agents` (default), `Mentions`, `All`.

One scroll, grouped by day with pinned day headers reading `Today`, `Yesterday`, or `Thursday, 14 August`.

- **Message rows** — kinds `note`, `comment`, `mention`, `handoff`. A speech bubble filled with the actor's hue at 10%, radius 10, with the actor chip, the relative time, and the body as rich markdown. Mentioned actors appear as chips in the header line, reading `Product → Ops, Comms`. A comment also shows the issue identifier as a capsule that navigates to it.
- **System rows** — kind `system`. One quiet line: a small symbol, the body in `callout` secondary, and the time. When the filter is `All` and three or more system rows are consecutive, they collapse into a disclosure reading `4 updates`.

Clicking a row navigates to whatever it references: an issue opens that project's Issues tab with the detail sheet, a capability or project opens the project home.

Activity is read-only. The composer lives on the project home, on purpose — there is one place to say something.

## Portfolio

Subtitle: `Every project at arm's length.`

This is the studio view of every app in one place. Cards only — not a table, not a markdown essay, no milestone block, and no studio-wide spine. The document column uses the same left-aligned, pane-width measure as the project home. No 720 island. No 1000 grid. Contents is hidden — there is no document.

### Project cards

A grid, cards between 300 and 460pt wide, 12pt gaps. One card per project, pinned or not.

Each card:

- The project mark, name in `heading`, key in `mono` `caption`.
- A pin control. Filled pin when pinned. Clicking the pin toggles pin and does not open the project.
- One-line summary — the first sentence of that project's `product/README.md`, or its stored `summary` if the documents have not loaded. If the lead starts with the project name, strip that prefix so the card does not read `Arkboard Arkboard is…`. This is the only human place for that copy.
- **Local** checkout path when `repoPath` is set, as `local · …`.
- **GitHub** remote when `githubRepo` is set, as `github · owner/name`.
- **Documents** — four small pills labelled `Design`, `Architecture`, `Mockups`, `Decisions`, filled in that section's hue when the document exists and hollow slate when it does not. Load from the same document bundle as the project home (local `product/` preferred when both sources exist).

Clicking the card (not the pin) opens that project's home. This page is the only place a human creates a project. A `New Project` control opens the existing sheet. After create, the project is pinned and selected.

## Timeline

Subtitle: `The studio calendar.`

Timeline is a destination. The master view is a cross-project calendar of every project's milestones (and dated shipped work the engine already has). Scale control: Week / Month / Year. Default Month. Each event shows the project's mark and name. Clicking a project's event opens that project's Timeline tab.

Same left-aligned, pane-width measure. No 720 island. No 1000 grid. Contents stays empty — do not invent a fake document outline.

## Onboarding

Subtitle: `How this studio works.`

Opened from the footer `sparkles` icon, not from Settings. The page renders `product/onboarding.md` as rich markdown. Thin header only — no article band, no composer. Contents lists that document's headings. This is the operating manual, not a settings duplicate.

## Project home

The most important screen in the app, and the one that must not look like a tracker.

Everything is inside **one** vertical scroll: the thin header scrolls away, the tab bar pins to the top when it reaches it, and the document continues underneath. The pane carries the wash of the selected tab. The thin header sits on plain `windowBackgroundColor` so it reads as chrome rather than as part of the section. The outline is the right Contents column, not a bar in this scroll. Header, tab rail, markdown, and project-home empty states share one left edge and one measure: the pane width, left-aligned, with pane padding only. When the sidebar and/or Contents are hidden, that measure grows with the pane — not a 720-centred island, and not a 1000 grid.

### Thin header

- The project mark at 28pt, the name in `display`, the key in a `mono` `caption` capsule.
- Trailing: the document source in `mono` `caption` — `local · product/` or `github · diliprt/arkboard` — a `Refresh` button with `arrow.clockwise`, and a note icon (`bubble.left`) that opens the compact composer sheet.
- No README lead. No article summary. No `More documents` chip row. Those documents stay reachable via tabs. The long description lives on Portfolio.

### Tab bar

Pinned. Capsule pills, 6pt apart, horizontally scrollable if the window is narrow.

`Design` · `Architecture` · `Mockups` · `Decisions & questions` · `Issues` · `Timeline`

The selected pill fills with its section hue at 16% and its label and symbol take the full hue. Unselected pills are secondary text on nothing. **Design is selected by default** — a project is a design object first.

Switching tabs cross-fades over 0.18s and returns the scroll to the top. `⌘[` and `⌘]` move between tabs. Landing on Mockups shows the tab rail and the gallery (or its empty state) immediately — the pane must not open scrolled past them.

### Document tabs

`Design`, `Architecture`, `Mockups`, and `Decisions & questions` all render `product/` markdown as a rich preview. Raw markdown is never the reading view.

When a tab holds more than one document, a rail of capsule chips sits above the content naming each one, with the primary selected. Otherwise the content starts directly.

**Decisions & questions** adds one thing: a strip of gold chips above the document, one per open question parsed from it, each jumping to its heading. Locked decisions do not get chips.

**Mockups** is a gallery, not a markdown essay. Large thumbs of every `png` / `jpg` / `webp` in `product/mockups/`, same left edge as Design. Click a thumb to preview (scaled to fit, arrows, Escape). Above the gallery, a lightweight screen-flow from `product/mockups/flow.md` or `flow.json` (nodes + edges). If neither file exists, infer a linear flow from the image filenames and label it inferred.

### Issues tab

Grouped rows scoped to this project. A `callout` line above them reads `Tracking only. Agents file and update these.` Clicking a row opens that issue's detail sheet. There is no jump to a studio Issues screen.

### Timeline tab

The same calendar as the master Timeline, filtered to this project. Scale control: Week / Month / Year. Default Month. Milestones are first-class. Completed issues may appear as lighter marks. Click-through from the master view lands here. Read-only. Agents set milestones through the API.

## New Project

The one creation sheet, 520pt wide.

| Field | Behaviour |
| --- | --- |
| Name | required |
| Key | auto-derived from the name, uppercased, 2–6 characters of `A–Z0–9`, editable, checked for uniqueness live |
| Colour | a row of ten swatches from the ramp |
| Icon | a grid of distinct SF Symbols; the unused mark for this key is preselected. Arkboard's layered-board mark is reserved. |
| Documents folder | optional folder picker, sets `repoPath` |
| GitHub repository | optional `owner/name`, used when there is no local folder |

Buttons `Cancel` and `Create Project`. Creating it pins the project and selects it.

## Settings

A standard Settings scene, 560 × 620, one `Form` with four sections.

**Appearance** — segmented `Light` / `Dark` / `System`.

**Text** — a `Text size` picker of `12`, `13 (default)`, `14`, `16`, and a `Text face` picker of the eight faces from [design.md](design.md). Below them, a live specimen card showing a heading, two lines of prose, a bullet, and an inline code span at the current settings, so the choice is visible before closing the window. Both apply app-wide the instant they change and persist.

**Studio** — the workspace name, and one row per project showing its resolved documents folder in `mono` `caption` with a `Choose…` button.

**Agents** — the server status dot and one of `Listening on 127.0.0.1:7420` or `Offline — port 7420 is in use`; then `MCP endpoint`, `REST base`, and `Database` in `mono` with copy buttons; then the stdio bridge command in a code block with a copy button.

## What is not in the human UI

Riyu does not manage work, so none of these exist on any screen. This list is a test to run against every future addition.

- **No status field.** No dropdown, no segmented control, no context-menu status change, no drag-between-columns. Status exists in the database and moves only through the API. Humans see grouping — Underway, Queued, Done — and nothing more.
- **No priority field.** Priority is never displayed, let alone edited. No urgency flags, no coloured priority bars, no sorting by priority.
- **No assignee picker.** No avatars on issues, no "assign to", no filter by person. Actors appear only in Activity, attached to things that were said or done.
- **No issue creation.** No New Issue button, no quick-add sheet, no `⌘⇧N`. Say it in the project composer.
- **No board, no swimlanes, no kanban.** The previous build carried a `BoardView` nobody ever opened.
- **No estimates, no points, no velocity, no burndown.**
- **No milestone editing.** Timeline is read-only.
- **No document editing.** `product/` is written in an editor and committed. Arkboard has no markdown text area outside the two composers, and no "save to product/" anywhere.
- **No MCP tool names in empty states.** An empty document does not teach the human to call `create_capability`. It says a director pass will write it, and stops.
- **No raw markdown in a reading view.**

The exception, deliberate and singular: **Archive** on an issue, with undo. Getting a stale row out of your reading view is hygiene, not management.

## Empty states

One shape everywhere: the section symbol at 28pt in the hue at 40%, a title in `heading`, one sentence in `callout` secondary. On the project home (Mockups, Design-not-written, Issues, Timeline, and the other document tabs) that block shares the document left edge — icon, title, and sentence leading, not a centred poster in the wash. Full-pane posters (no projects, Monitor, Activity) stay centred, with 40pt of air. No buttons unless the table says so.

| Where | Title | Sentence |
| --- | --- | --- |
| No projects at all | `No projects yet` | `Create one and point it at a repository with a product/ folder.` — plus a `New Project` button |
| Monitor, no questions | `No open questions` | `Nothing is waiting on you right now.` |
| Monitor, nothing broken | `Nothing is broken` | `Every capability agents have checked is working.` |
| Monitor, nothing at all | `Quiet studio` | `No open questions and nothing broken. Say something to the team above.` |
| Design tab, no document | `Design is not written yet` | `A director pass will write this.` |
| Architecture tab, no document | `Architecture is not written yet` | `A director pass will write this.` |
| Mockups tab, no frames | `No mockups yet` | `A director pass will drop screenshots here.` |
| Decisions tab, no document | `No decisions written yet` | `A director pass will write this.` |
| Overview, no README | `No overview yet` | `A director pass will write this.` |
| Documents failed to load | `Documents could not be read` | The reason, verbatim, plus a `Try again` button |
| Issues, none in scope | `No issues` | `Nothing has been filed here.` |
| Issues, search finds nothing | `No matching issues` | `Try a different search or widen the scope.` |
| Issues, archived empty | `Nothing archived` | `Archived issues stay here until an agent restores them.` |
| No issue selected | `Select an issue` | `Pick one from the list to read it.` |
| Issue has no body | — | `No description yet.` in `callout` secondary, inline |
| Issue has no comments | — | `No comments yet.` in `callout` secondary, inline |
| Activity, empty | `Nothing said yet` | `Notes from you and from agents show up here.` |
| Timeline, empty | `Nothing planned yet` | `Milestones and shipped work appear here.` |
| Portfolio, no projects | `No projects yet` | `Create one to see it here.` |

"A director pass will write this." is used verbatim in four places. That is intentional; it is the house phrase for a document that has not been written.

## Keyboard

| Shortcut | Action |
| --- | --- |
| `⌘N` | open the compact project note sheet |
| `⌘↩` | send the focused composer |
| `⌘F` | open the current project's Issues tab |
| `⌘R` | reload the selected project's documents |
| `⌘[` `⌘]` | previous and next project tab |
| `⌘,` | Settings |

`⌘N` is deliberately bound to talking, not to filing. There is no shortcut that creates an issue.

## Acceptance

The UI is done when all of these are true on a clean machine.

1. Launching from `./scripts/run.sh` restores the last sidebar row. The left sidebar is Portfolio, then Timeline, a hairline, then pinned projects — no Origin Ark row — and does not contain Monitor or Issues. Selecting a pinned project opens the document home (thin header, six tabs, Design selected, markdown preview), not empty white.
2. The Arkboard row uses `square.3.layers.3d` in indigo, not a generic blue dot. A second project, if present, uses a different symbol.
3. The project home shows a thin header (mark, name, key, source, refresh, note icon), six tabs, Design selected, and no article summary.
4. The Design, Architecture, and Decisions tabs each render this design pack as headings, prose, tables, lists, code blocks, and quotes. No `#` characters are visible as text.
5. The right column is labelled `Contents` and lists this page's headings. Clicking a heading scrolls the same document scroll to that subsection. There is no `On this page` chip rail.
6. Scrolling the project home moves the overview off screen and pins the tab bar; only one scrollbar is ever visible over the document. Contents is its own column.
7. Switching from Design to Architecture visibly changes the pane wash from rose to azure, and the Contents list updates to that document's headings.
8. Decisions & questions shows a gold chip for each `Open —` heading; clicking it jumps to that heading.
9. Settings changes the text size to 16 and the face to Georgia, and every screen — titles, chips, captions, document bodies, sidebar — follows. Relaunching keeps it.
10. Dark mode is legible on every screen, with no fixed light-mode colour left behind.
11. No screen anywhere offers a status, priority, or assignee control, and no screen offers a way to create an issue.
12. An issue created through the API appears in the project's Issues tab without touching the app, and a note posted through the API is stored as Activity the same way.
13. Every empty state matches the copy in the table above.
