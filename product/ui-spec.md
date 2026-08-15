# UI specification

Every surface in Arkboard, what it contains, and what it refuses to contain. Colours, sizes, and the type scale come from [design.md](design.md); this document names the screens and the words on them.

Copy in fixed-width in the tables below is literal. Ship those strings.

## The shell

A single window. `NavigationSplitView` with a sidebar and a detail column, except on the Issues screen, which uses three columns.

- Minimum 1080 × 700, default 1320 × 860, `.windowStyle(.automatic)`, unified toolbar.
- The selected sidebar row is restored on launch from `arkboard.sidebarSelection`.
- The window title is the current screen or project name; the subtitle is the workspace name.

### Sidebar

232pt wide, `.sidebar` list style, one selection.

**Header** — a `building.2` symbol in indigo and the workspace name in `bodyStrong`.

**Studio**, in this order and no other:

| Row | Symbol | Hue |
| --- | --- | --- |
| Monitor | `binoculars` | indigo |
| Issues | `tray.full` | teal |
| Activity | `bubble.left.and.bubble.right` | ember |
| Portfolio | `square.grid.2x2` | violet |

**Projects** — one row each: an 8pt dot in the project's colour, the name in `body`, and the key in `mono` `caption` trailing, right-aligned and secondary. Sorted by `sortOrder` then name.

**Footer**, pinned, on `.bar`:

- A 7pt dot and `Agents · :7420` in `caption`. Moss when the server is listening, crimson and `Agents offline` when it is not. Clicking opens Settings to the Agents section.

**Toolbar** — a single `folder.badge.plus` button that opens New Project. This is the only creation affordance in the entire human UI.

### Screen header

Every studio screen opens the same way, fixed above the scroll:

1. Section symbol at `heading` size in the section hue.
2. Title in `title`.
3. A one-line subtitle in `callout`, secondary.
4. Optional trailing controls.
5. A 1pt divider in the section hue at 22%.

The pane below carries the section wash. Everything under the header lives in exactly one vertical scroll.

## Monitor

The default screen. Subtitle: `What needs you, and what is broken.`

Questions come first because Riyu is the only one who can answer them. Broken things come second because agents can fix those without being asked.

### Composer

A card at the top of the scroll, `controlBackgroundColor`, radius 10, indigo stroke at 14%.

- Riyu's avatar in moss, then a multi-line text field that grows from one line to five, placeholder `Tell the team…`.
- A scope menu on the trailing edge reading `to Studio` or `to Arkboard`, listing Studio and every project.
- A `Send` button, disabled while empty, with `⌘↩` as the shortcut and `⌘↩` shown in `caption` beside it.
- Sending posts an activity note authored by `Riyu` and clears the field. The new note appears at the top of Activity immediately.

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

Three columns. Subtitle: `Tracking. Agents file and update these.`

### List column

Fixed header: a search field with placeholder `Search issues`, a scope menu reading `All projects` or a project name, and an `Archived` toggle.

One scroll below it, a `LazyVStack` with pinned group headers — never a `List` inside a `ScrollView`. Groups in this order, each shown only when it has rows:

| Group header | Contains |
| --- | --- |
| `Underway` | status `in_progress` |
| `Queued` | status `backlog` and `todo` |
| `Done` | status `done`, completed in the last 14 days, newest first |
| `Archived` | `archivedAt` set, only when the toggle is on |

Group headers are uppercase `caption` in teal with a count.

A row is one line of identifier in `mono` `caption`, then the title in `body`, then label chips, then the relative updated time trailing in `caption`. When the scope is All projects, a project dot and key precede the identifier. Selected rows fill teal at 12%.

There is no status pill on a row. The group is the status, and that is all the status a human needs.

Right-clicking a row offers `Copy identifier`, `Copy title`, and `Archive`.

### Detail column

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

Clicking a row navigates to whatever it references: an issue opens Issues with it selected, a capability or project opens the project home.

Activity is read-only. The composer lives on Monitor, on purpose — there is one place to say something.

## Portfolio

Subtitle: `Every project at arm's length.`

One scroll, capped at 1000pt.

### Totals

A row of four chips in violet: `Projects`, `Open issues`, `Questions waiting`, `Not working`. Numbers in `title`, labels in `caption`.

### Project cards

A grid, cards between 300 and 460pt wide, 12pt gaps.

Each card:

- The project dot, name in `heading`, key in `mono` `caption`.
- One line of summary — the first sentence of that project's `product/README.md`, or its stored `summary` if the documents have not loaded.
- **Documents** — four small pills labelled `Design`, `Architecture`, `Mockups`, `Decisions`, filled in that section's hue when the document exists and hollow slate when it does not. This is the most useful thing on the card: it shows at a glance which projects have been thought through.
- A counts line: `Underway 2 · Queued 7 · Done 31`.
- A footer line for the next milestone: a moss or gold dot, its title, and its date. Omitted when there is none.
- Badges for `3 questions` in gold and `1 not working` in crimson when non-zero.

Clicking a card opens that project's home.

### Milestones

Section header `Milestones`. The shared timeline component with no project filter: studio-wide milestones first, then per project, on one spine ordered by date with a `Today` rule.

## Project home

The most important screen in the app, and the one that must not look like a tracker.

Everything is inside **one** vertical scroll: the overview scrolls away, the tab bar and outline pin to the top when they reach it, and the document continues underneath. The pane carries the wash of the selected tab. The overview band sits on plain `windowBackgroundColor` so it reads as a header rather than as part of the section.

### Overview band

- The project dot at 10pt, the name in `display`, the key in a `mono` `caption` capsule.
- Trailing: the document source in `mono` `caption` — `local · product/` or `github · diliprt/arkboard` — a relative `loaded 2m ago`, and a `Refresh` button with `arrow.clockwise`.
- Below that, the lead of `product/README.md` — everything before its first `##` — rendered as rich markdown, not truncated, because it is inside the scroll.
- If any documents did not route to a tab, a `More documents` row of chips that select the tab holding each one.

### Tab bar

Pinned. Capsule pills, 6pt apart, horizontally scrollable if the window is narrow.

`Design` · `Architecture` · `Mockups` · `Decisions & questions` · `Issues` · `Timeline`

The selected pill fills with its section hue at 16% and its label and symbol take the full hue. Unselected pills are secondary text on nothing. **Design is selected by default** — a project is a design object first.

Switching tabs cross-fades over 0.18s and returns the scroll to the top. `⌘[` and `⌘]` move between tabs.

### Outline bar

Pinned directly under the tab bar on document tabs whose primary document has two or more headings.

- A leading `On this page` menu listing every heading, indented by level.
- Then a horizontally scrolling row of `##` chips in the section hue at 12%.
- Both scroll the pane to that heading, landing it at the top, over 0.2s.

### Document tabs

`Design`, `Architecture`, `Mockups`, and `Decisions & questions` all render `product/` markdown as a rich preview. Raw markdown is never the reading view.

When a tab holds more than one document, a rail of capsule chips sits above the content naming each one, with the primary selected. Otherwise the content starts directly.

**Decisions & questions** adds one thing: a strip of gold chips above the document, one per open question parsed from it, each jumping to its heading. Locked decisions do not get chips.

**Mockups** replaces the prose column with a grid — two columns above 900pt, one below — of images at radius 10 with their filename as a caption, followed by any notes in that folder rendered as prose. Clicking an image opens a viewer sheet with the frame scaled to fit, arrow keys moving between frames, and Escape closing it.

### Issues tab

The same grouped rows as the Issues screen, scoped to this project and read-only. A `callout` line above them reads `Tracking only. Agents file and update these.` Clicking a row opens the Issues screen with that project scoped and that issue selected.

### Timeline tab

A vertical spine ordered by date, oldest at the top, with a `Today` rule and the initial scroll positioned there.

- Milestones are the primary events: a dot in moss when done, gold when in progress, crimson when missed, slate when planned, the title in `bodyStrong`, the date in `caption`, the description as one line, and related issue identifiers as chips.
- Completed issues appear as light rows under the week they were completed: a small moss dot, the identifier, and the title.
- Week headers read `Week of 11 August` in uppercase `caption`, moss.

Read-only. Agents set milestones through the API.

## New Project

The one creation sheet, 520pt wide.

| Field | Behaviour |
| --- | --- |
| Name | required |
| Key | auto-derived from the name, uppercased, 2–6 characters of `A–Z0–9`, editable, checked for uniqueness live |
| Colour | a row of ten swatches from the ramp |
| Documents folder | optional folder picker, sets `repoPath` |
| GitHub repository | optional `owner/name`, used when there is no local folder |

Buttons `Cancel` and `Create Project`. Creating it selects the new project.

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
- **No issue creation.** No New Issue button, no quick-add sheet, no `⌘⇧N`. Say it in the Monitor composer.
- **No board, no swimlanes, no kanban.** The previous build carried a `BoardView` nobody ever opened.
- **No estimates, no points, no velocity, no burndown.**
- **No milestone editing.** Timeline is read-only.
- **No document editing.** `product/` is written in an editor and committed. Arkboard has no markdown text area outside the two composers, and no "save to product/" anywhere.
- **No MCP tool names in empty states.** An empty document does not teach the human to call `create_capability`. It says a director pass will write it, and stops.
- **No raw markdown in a reading view.**

The exception, deliberate and singular: **Archive** on an issue, with undo. Getting a stale row out of your reading view is hygiene, not management.

## Empty states

One shape everywhere: the section symbol at 28pt in the hue at 40%, a title in `heading`, one sentence in `callout` secondary, centred, with 40pt of air. No buttons unless the table says so.

| Where | Title | Sentence |
| --- | --- | --- |
| No projects at all | `No projects yet` | `Create one and point it at a repository with a product/ folder.` — plus a `New Project` button |
| Monitor, no questions | `No open questions` | `Nothing is waiting on you right now.` |
| Monitor, nothing broken | `Nothing is broken` | `Every capability agents have checked is working.` |
| Monitor, nothing at all | `Quiet studio` | `No open questions and nothing broken. Say something to the team above.` |
| Design tab, no document | `Design is not written yet` | `A director pass will write this.` |
| Architecture tab, no document | `Architecture is not written yet` | `A director pass will write this.` |
| Mockups tab, no frames | `No mockups yet` | `Frames dropped into product/mockups/ show up here.` |
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
| `⌘1` – `⌘4` | Monitor, Issues, Activity, Portfolio |
| `⌘N` | go to Monitor and focus the composer |
| `⌘↩` | send the focused composer |
| `⌘F` | focus the Issues search field |
| `⌘R` | reload the selected project's documents |
| `⌘[` `⌘]` | previous and next project tab |
| `⌘,` | Settings |

`⌘N` is deliberately bound to talking, not to filing. There is no shortcut that creates an issue.

## Acceptance

The UI is done when all of these are true on a clean machine.

1. Launching from `./scripts/run.sh` opens Arkboard with Monitor selected and the sidebar reading Monitor, Issues, Activity, Portfolio, Arkboard.
2. Clicking **Arkboard** shows the overview band with the README lead rendered as rich markdown, six tabs, and Design selected.
3. The Design, Architecture, and Decisions tabs each render this design pack as headings, prose, tables, lists, code blocks, and quotes. No `#` characters are visible as text.
4. Each of those tabs shows an outline bar, and choosing a heading scrolls the same scroll view to it.
5. Scrolling the project home moves the overview off screen and pins the tab bar and outline; only one scrollbar is ever visible over the content.
6. Switching from Design to Architecture visibly changes the pane wash from rose to azure.
7. Decisions & questions shows a gold chip for each `Open —` heading, and Monitor lists those same questions.
8. Settings changes the text size to 16 and the face to Georgia, and every screen — titles, chips, captions, document bodies, sidebar — follows. Relaunching keeps it.
9. Dark mode is legible on every screen, with no fixed light-mode colour left behind.
10. No screen anywhere offers a status, priority, or assignee control, and no screen offers a way to create an issue.
11. An issue created through the API appears in the Issues list without touching the app, and a note posted through the API appears in Activity the same way.
12. Every empty state matches the copy in the table above.
