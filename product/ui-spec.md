# UI specification

Every surface in Arkboard, what it contains, and what it refuses to contain. Colours, sizes, and the type scale come from [design.md](design.md); this document names the screens and the words on them.

Copy in fixed-width in the tables below is literal. Ship those strings.

## The shell

A single window. `NavigationSplitView` with two columns: the project portfolio and the current page. Contents is a trailing overlay on the document column — Mail.app / Apple Music inspector energy — not a third split column, which collapsed the page to empty white, and not an `HStack` sibling that steals width from the document.

- Minimum 1080 × 700, default 1320 × 860, `.windowStyle(.automatic)`, unified toolbar.
- The selected row is restored on launch from `arkboard.sidebarSelection`. Valid values are `portfolio`, `timeline`, `onboarding`, or `project:<id>`. Leftover studio chrome (`monitor`, `issues`, `activity`) is discarded and Portfolio is selected.
- The window title is Portfolio, Timeline, Onboarding, or the current project name; the subtitle is the workspace name. **This is the only title in the app.** No screen prints its own name again in the pane below, and no screen carries a tagline under that name. Content starts directly under the toolbar.

### Materials

Arkboard speaks Apple's design language. It does not borrow Apple's content, screens, or copy.

Liquid Glass is the **navigation** layer and only the navigation layer: the sidebar, the window toolbar, the project tab rail, and the Contents inspector. The document is the **content** layer — solid, readable, and never glassed. A page of prose on glass is unreadable and is the one mistake this rule exists to prevent.

- **Take the system's material, never paint your own.** A custom background behind a navigation surface sits on top of the glass and blocks it. No `windowBackgroundColor` slab under the sidebar, the tab rail, the Contents column, a pinned header, or the project identity strip. The sidebar list hides its own scroll background so the column's material shows through. Section hue survives as a wash *over* that material, not as an opaque fill beside it.
- **The two columns are different surfaces, on purpose.** The sidebar is frosted system material; the document is an opaque reading field with the section wash over it. Side by side they read as slightly different colours, and that difference is the whole navigation-versus-content split made visible. `StudioColor.documentField` exists for the document alone: `paneBackground` is the only caller, and painting it on a navigation surface is exactly the mistake the rule above forbids.
- **The pane fill runs edge to edge.** The document's field and wash ignore the safe area so they continue beneath the floating sidebar; the scrolling content stays inside the safe area, so nothing is clipped and nothing is hidden. Arkboard deliberately does not use a background extension effect: it mirrors and blurs whatever is adjacent, which is right for a hero image and wrong for a column of prose, where it reads as ghost text behind the sidebar.
- **Bars are bars.** A control strip pinned to the edge of a column is a safe-area bar, so the system insets the content and extends the scroll edge effect underneath it. It is not a floating widget carrying its own material.
- **Filters are native capsules.** Anything that narrows what you are reading — the project tab rail, the document chip rail — is a system accessory-bar capsule with the section hue as its tint. The shape, the hit target, the hover, and the selected state are the system's. No hand-drawn pill with a hand-mixed fill; that is what makes an app look like it came from somewhere else.
- **One radius family, concentric.** A surface nested inside another takes the container's radius less the inset between them, so the two curves share a centre. Radii are derived in `Metrics`, not typed in at each call site.
- **One type scale, one face.** Every glyph and every label — sidebar, tab rail, toolbar, cards, empty states — takes a role from the `typography` environment. SF Symbols in chrome sit at body size and grow with the Settings text size. No `.font(.system(size:))` anywhere a human reads.
- **A mark is a product icon, not type.** The one exception to the rule above. A project mark is a glyph on a tile, so its corner and its glyph are fractions of the tile off the icon grid (`Metrics.markCorner`, `Metrics.markGlyph`) rather than roles from the type scale. That is why the same `ProjectIcon` reads correctly at 22pt in the sidebar and at hero size on a Portfolio card. Nothing else in the app may size itself this way.
- **Section headers are title case.** Lists and tables read `Underway`, not `UNDERWAY`.
- **Controls size themselves.** No hard-coded control heights; the rails and bars grow with the type scale and with the platform's control metrics.

On macOS 14 and 15 every one of these resolves to the system material of that release. On Tahoe, built with Xcode 26, the same surfaces become Liquid Glass. There is no third, hand-rolled appearance.

### Sidebar

232pt wide, `.sidebar` list style, one selection. There is no Studio section. The workspace name lives in the window subtitle, not in this column. No workspace icon, no fake destination.

The column is the system's glass and nothing else is painted behind it.

**The selected row is always the system's unemphasized selection — the quiet grey — including when the sidebar has focus.** Never the accent blue. A saturated fill forces the row's content to white, which erases the project's mark and its key, and those are the two things the row exists to show. Mark, name and key keep their own colours in every state, and destination symbols keep their section hue.

This is not a colour we paint. `unemphasizedSelectedContentBackgroundColor` is a colour to draw *with*, not a mode to switch on: AppKit picks the emphasized or unemphasized style from whether the list is first responder, and a `tint` reaches the row's icons and stops there. Finder, Mail and Music keep their sidebars from taking first responder, and Arkboard does the same. Do not "fix" this by tinting the list, and do not hand-draw a grey capsule behind the row.

**Pacing.** The navigation column is paced more loosely than the document. Every row takes `Metrics.sidebarRowY` of air above and below its content, and the hairline between the destinations and the pins takes the same, so the column reads as a short list of places rather than a dense table. Row height follows from that air plus the type scale; it is never a fixed number. There are no all-caps section headers anywhere in this column, and no section header at all above the pins.

**Destinations**, in this order:

1. **Portfolio** — a real row. Portfolio is a destination. Selecting it shows the Portfolio page in the document column.
2. **Timeline** — a real row. Timeline is a destination. Selecting it shows the master studio rollup: every project's plan as a Gantt.

A single hairline `Divider` sits between those two destinations and the pinned projects below. Not a section header that says `Projects`.

**Pinned projects** — under that hairline, only projects whose `pinned` flag is true, sorted by `sortOrder` then name. Clicking a pinned row opens that project's document home (Design default). Unpinning removes the row from the sidebar; the project stays on the Portfolio page. Pinning puts it back. Existing projects start pinned so Arkboard does not disappear on first launch.

Each project row: the project's persisted mark (22pt), the name in `body`, and the key in `mono` trailing, right-aligned and tertiary so it never competes with the name. The mark is that app's brand — an SF Symbol on a colour-washed tile whose corner comes off the icon grid, or an image from `product/icon.png` / `product/mark.png` / `product/logo.png` when one exists. It is never the same blue dot for every project. A context menu on the row offers `Pin` / `Unpin` and `Chat with Chief of Staff`.

Arkboard's own mark is `square.3.layers.3d` in indigo `#5A62D6`. Other projects get a distinct symbol (and a distinct colour when they would otherwise share indigo).

**Not in this sidebar.** Monitor and Issues are leftover ticket chrome. Issues stay as a tab on the project page. Monitor is not a studio row. Activity is not a row.

**Footer**, pinned to the bottom of this same column as a safe-area bar. It sits on the sidebar's own material; it does not carry a second one of its own.

- **Onboarding** — a `sparkles` icon at body size, help text `Onboarding`. Not labelled Setup. Not a gear. Clicking it opens the Onboarding page in the document column.
- A 7pt dot and `Agents · :7420` in `caption`. Moss when the server is listening, crimson and `Agents offline` when it is not. Clicking opens Settings to the Agents section.

Create is not in this column.

### Contents

A trailing overlay that floats over the right edge of the document on edge-to-edge glass — the inspector language, on the trailing side. It is not a split column.

**The prose reserves a gutter for it.** "Does not steal width" is not a pass if the last words of every line are unreadable under the overlay. When Contents is open the document reflows with a trailing gutter exactly as wide as the overlay, so no glyph is ever printed underneath it. That is an inset on the text, not a third `NavigationSplitView` column and not a 720 island: the page still measures the whole pane, and closing Contents returns the full width immediately. The document measure does not collapse. 220pt ideal, 180 min, 280 max, user-resizable in that range. The choice persists as `arkboard.contentsVisible`. The document column itself is at least 560pt and always uses the full pane width, Contents shown or hidden. This is the outline. Do not put it on the left. Do not also pin an `On this page` chip rail — one outline, on the right. Do not bring back a third `NavigationSplitView` column, a `GridColumn` 1000, or a 720 island. Nothing opaque is painted behind it; the glass is the surface.

The toggle lives in the window toolbar, on toolbar glass: a `sidebar.trailing` control that carries a selected state while Contents is open, help text `Show Contents` / `Hide Contents`.

- Header `Contents` in `caption`, secondary.
- One heading per row, indented 12pt per level below `#`, `bodyStrong` for `#`/`##` and `caption` deeper.
- Clicking a heading scrolls the current page to that subsection, landing it at the top, over 0.2s.
- Shown when the current document tab has two or more headings. Otherwise a quiet `This page has no subsections.` in `callout` tertiary. Issues, Timeline, and Mockups without headings use that empty line.

### Titles

**There is no in-page screen header.** The window title bar carries the title and the subtitle, and that is the whole of it. A screen that printed its own name again — a section symbol, a large title, a tagline, a hue divider — said the same word twice, one above the other, and spent the top of every pane doing it. That band is void. Do not bring it back on any screen, and do not bring back a `ScreenHeader` view to render it.

What replaces it, per screen:

| Screen | Window title | What starts the pane |
| --- | --- | --- |
| Portfolio | `Portfolio` | the cards |
| Timeline | `Timeline` | the chart, with its own `Week` / `Month` / `Quarter` control |
| Onboarding | `Onboarding` | the document |
| A project | the project name | the tab rail |

**Timeline has no in-page title.** The pane opens on the scale control and the Gantt, with nothing above them.

The title also sits on **one row, on every screen**. Left to itself, AppKit gives the title its own line beneath the toolbar when a screen carries few toolbar items, and takes it inline when there are more — so Timeline, which has only the Contents toggle, grew a second row while Portfolio and the project page kept theirs inline. A title and subtitle stacked in their own band under the toolbar reads as exactly the in-page headline this section deletes, even though no view is drawing one. The window uses the inline title display mode so every screen looks the same.

Page actions belong in the window toolbar on toolbar glass — `New Project` on Portfolio, the Contents toggle everywhere. A screen-level filter or scale control may sit as a quiet native control at the top of its own content, next to the thing it filters. Neither is a headline.

The pane below carries the section wash, and everything in it lives in exactly one vertical scroll.

## Monitor

**Engine, not a screen.** Monitor is not a sidebar row and has no destination, so nothing below renders as a studio page today. The engine — open questions parsed from Decisions, capabilities that are not working — is real and stays, because agents read it and the project page uses it. The sections that follow describe what that engine computes and how those cards look *if* they are ever placed, not a screen a human can currently open.

Where its output surfaces today: open questions become the gold chips above the Decisions tab, and studio health is the dot in the sidebar footer and the Agents section of Settings. Do not read this section as a brief to add a Monitor row back to the sidebar.

### Composer

A compact sheet titled `Chat with Chief of Staff` — the same words as the menu — opened from the project-home header icon (or `⌘N`), not a large box in the project scroll. The same sheet opens from any page — Portfolio, Timeline, Onboarding, or a project — when the human chooses that menu item.

- A short field, placeholder `Tell the team…`, `Send` with `⌘↩`.
- **History** of notes for this project from existing Activity. No second store. On Portfolio / Timeline / Onboarding the note is studio-scoped (`projectId` empty).
- Sending posts through the existing Activity / `post_note` engine, authored by `Riyu`, and clears the field.

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

Group headers are title-case `caption` in teal with a count — `Underway`, not `UNDERWAY`. They pin to the top of the scroll on bar material, so rows stay legible as they pass beneath.

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

Not a sidebar row either. Like Monitor, this describes the engine's reading view rather than a screen a human can currently open.

A segmented filter sits at the top of the content — `People & agents` (default), `Mentions`, `All` — as a plain native control, not under a title band.

One scroll, grouped by day with pinned day headers reading `Today`, `Yesterday`, or `Thursday, 14 August`.

- **Message rows** — kinds `note`, `comment`, `mention`, `handoff`. A speech bubble filled with the actor's hue at 10%, radius 10, with the actor chip, the relative time, and the body as rich markdown. Mentioned actors appear as chips in the header line, reading `Product → Ops, Comms`. A comment also shows the issue identifier as a capsule that navigates to it.
- **System rows** — kind `system`. One quiet line: a small symbol, the body in `callout` secondary, and the time. When the filter is `All` and three or more system rows are consecutive, they collapse into a disclosure reading `4 updates`.

Clicking a row navigates to whatever it references: an issue opens that project's Issues tab with the detail sheet, a capability or project opens the project home.

Activity is read-only. The composer lives on the project home, on purpose — there is one place to say something.

## Portfolio

The studio view of every app in one place. The window title says Portfolio, so the pane opens straight onto the cards — no symbol, no repeated title, no tagline.

Cards only — not a table, not a markdown essay, no milestone block, and no studio-wide spine. The document column uses the same left-aligned, pane-width measure as the project home. No 720 island. No 1000 grid. Contents is hidden — there is no document.

`New Project` is a toolbar item on toolbar glass, a `plus` symbol with the help label `New Project`, contributed by this page. It is not a button inside the content, and it is still not in the sidebar.

### Project cards

**Posters, not forms. The card is the picture.**

A grid, cards between 320 and 480pt wide, 12pt gaps. One card per project, pinned or not. Cards are content, so they are a solid surface with one hairline stroke and concentric corners — never glass.

Each card is a full-bleed image with a short caption under it. The picture runs edge to edge to the card's rounded corners at `Metrics.cardPosterAspect`, so every tile in the grid lines up whatever artwork it is given. Resolution order:

1. `product/card.png` — the project's generated poster. This is the intended face.
2. `product/icon.png` / `mark.png` / `logo.png` — the small mark, stretched to the poster box, when there is no card yet.
3. No image at all — a field in the project's own colour carrying its SF mark. A placeholder that still looks designed. Never a 22pt chip beside a stack of metadata, which is what made the old tile read as a row in a table rather than a thing you want to open.

Brand artwork lives at the root of `product/` and is the project's own face, so it never appears in the Mockups gallery. A frame the director drew belongs in `product/mockups/`.

Under the picture, quietly:

- The name in `heading`.
- A pin control at the end of that line. Filled pin when pinned. Clicking the pin toggles pin and does not open the project.
- One-line summary in `callout`, secondary, clamped to two lines — the first sentence of that project's `product/README.md`, or its stored `summary` if the documents have not loaded. If the lead starts with the project name, strip that prefix, and strip the copula it strands with it: `Arkboard is Origin Ark Studio's board` becomes `Origin Ark Studio's board`, not `is Origin Ark Studio's board`. A card line always opens on a capital and reads as a sentence someone wrote.

**Not on the tile.** Checkout paths, the GitHub remote, and the four document words are gone. They are metadata, and metadata is not a poster; they belong to the project page, which is one click away.

Each card uses the same `typography` environment as the project home, the sidebar, and documents — one scale, one face. No one-off `.font(.system)` and no custom faces. Settings text size and face flow through.

Clicking the card (not the pin) opens that project's home. This page is the only place a human creates a project. A `New Project` control opens the existing sheet. After create, the project is pinned and selected.

## Timeline

The window title says Timeline. The pane opens on the chart itself — no repeated title, no tagline — with the scale control as the only chrome above the rows.

Timeline is a destination, and it is a Gantt: a project plan, not a month grid of days. Rows are the studio's broader projects; each project's milestones sit underneath it. Bars run left to right across one shared time axis, and dependency links join a milestone to the ones it waits on. This is the studio rollup — the view that answers "what is every project doing between now and Christmas", which a grid of dated cells cannot.

Scale control: `Week` / `Month` / `Quarter`. Default Month. The scale only decides how wide one gridline column is; the shape is always bars on a timeline.

### Rows

| Row | Contains |
| --- | --- |
| Project | The project mark, name in `bodyStrong`, and its milestone count. One bar in the project's colour spanning its earliest dated work to its latest. |
| Milestone | The title in `body` and the target date in `caption`, indented under its project. A thinner bar in the status colour, ending in a diamond on the target date. |

A project with no milestones and no dated work has no row. Milestones with no project belong to a `Studio` row at the bottom, which is not clickable.

A milestone holds one date, so its bar starts at whatever must land first: the latest target date among its predecessors, or its project's own start when it has none. A predecessor dated after its successor never inverts a bar.

Completed issues the engine has already dated appear as small moss ticks on their project's bar — shipped work in context, not rows of their own.

### Time axis

Fixed above the rows, one label per column — `10 Aug`, `Aug 2026`, `Q3 2026` — on a hairline. Columns stretch to fill the pane; when that would squeeze a column below a legible width the chart scrolls horizontally and the row labels stay put. Week columns start on Monday.

Exactly one `Today` rule: a moss line through every row, with the word on the axis. The window always has room for it, whether the plan is entirely past, entirely future, or empty.

### Dependencies

A milestone's `dependsOn` holds predecessor milestone ids. The chart draws one elbow link per predecessor, from that milestone's diamond into the successor's bar start, with an arrowhead. A predecessor that is not on the current chart draws no link. Agents write dependencies through `create_milestone` / `update_milestone`; the API rejects a missing id, a self-reference, and any cycle.

### Read-only

Humans read this chart and nothing else. No status editor, no priority editor, no drag to reschedule, no milestone form. Status is colour — moss done, gold underway, crimson missed, slate planned — and a hover line naming the status, the date, and what the milestone comes after. Agents set every one of those fields through the API.

Clicking a project row or its bar opens that project's Timeline tab. Same left-aligned, pane-width measure. No 720 island. No 1000 grid. Contents stays empty — do not invent a fake document outline.

## Onboarding

Opened from the footer `sparkles` icon, not from Settings. The window title says Onboarding, so the document starts directly under the toolbar — no title band, no tagline, no article band, no composer. The page renders `product/onboarding.md` as rich markdown, and Contents lists that document's headings. This is the operating manual, not a settings duplicate.

## Project home

The most important screen in the app, and the one that must not look like a tracker.

Everything is inside **one** vertical scroll, and the tab rail is the first thing in it, so the rail is pinned from first paint and there is nothing above it that can push it around. The document scrolls underneath. The pane carries the wash of the selected tab over the document field. The outline is the right Contents overlay, not a bar in this scroll. Tab rail, markdown, and project-home empty states share one left edge and one measure: the pane width, left-aligned, with pane padding only. When the sidebar is hidden, that measure grows with the pane. Contents reserves a trailing gutter and does not change the measure — not a 720-centred island, and not a 1000 grid.

**One headline.** The window title bar names the page and the tab rail names the section. A document that opens with an H1 saying the same thing — `# Design` under the Design tab — is a second headline, so that heading is not rendered and does not appear in Contents. The markdown file is untouched; only the repeated opener is skipped, and a document with its own title (`# UI specification` under Design) keeps it.

### Identity on the toolbar

There is no identity strip in the pane. The window title bar already says the project's name, and a mark-plus-key row under it is a second logo row saying the same thing again. Identity lives in the toolbar beside the title, and **the pane starts at the tab rail**.

- Leading, next to the window title: the project mark at `Metrics.markSidebar` and the key in `mono`, secondary.
- Trailing: `Refresh` (`arrow.clockwise`), whose help text names the document source — `Reload local · product/` or `Reload github · diliprt/arkboard` — and a note action (`bubble.left`) that opens the compact composer sheet.
- No name in `display`, and no name in the pane at all. No README lead. No article summary. No `More documents` chip row. Those documents stay reachable via tabs. The long description lives on Portfolio.

### Tab bar

Pinned, and it is navigation, so it sits on the glass layer carrying the selected tab's wash. Nothing opaque is painted behind it and there is no hairline under it — the material is the separation.

Each tab is a native accessory-bar capsule: an SF Symbol and a label at body size, tinted with the section hue, 6pt apart, horizontally scrollable when the pane is narrow. The selected capsule is the system's selected state, not a fill we mixed. The rail sizes itself to the control metrics and to the current text size; it has no fixed height.

`Design` · `Architecture` · `Mockups` · `Decisions & questions` · `Issues` · `Timeline`

**Design is selected by default** — a project is a design object first. Clicking the already-selected tab does nothing; a filter cannot be turned off, only moved.

**The rail does not move.** Switching tabs returns the scroll to the top of the tab body — every tab, the same way — and nothing about that switch is animated. The rail stays put; Design → Mockups → Design does not shift it by a pixel. The selected capsule scrolls itself into view horizontally. `⌘[` and `⌘]` move between tabs. Landing on Mockups shows the tab rail and the gallery (or its empty state) immediately — the pane must not open scrolled past them.

Three rules keep that true, and all three are load-bearing:

1. **The scroll target is never the rail.** The rail is a pinned header, which the scroll view repositions itself; scrolling *to* it chases a moving target, and that is what made the pane bounce. The anchor is the top of the tab body.
2. **The reset is unanimated.** An eased scroll can still be in flight when the next layout pass lands, and the two fight.
3. **The gallery's height is known before it paints.** Mockup cells are a fixed height, so the grid does not grow as thumbnails materialise and shove the pane around a frame late.

### Document tabs

`Design`, `Architecture`, `Mockups`, and `Decisions & questions` all render `product/` markdown as a rich preview. Raw markdown is never the reading view.

When a tab holds more than one document, a rail of native accessory-bar capsules sits above the content naming each one, with the primary selected — the same control as the tab rail, at the same size, tinted the same hue. Otherwise the content starts directly.

**Decisions & questions** adds one thing: a strip of gold chips above the document, one per open question parsed from it, each jumping to its heading. Locked decisions do not get chips.

**Mockups** is a gallery, not a markdown essay. Large thumbs of every `png` / `jpg` / `webp` in `product/mockups/`, same left edge as Design. Click a thumb to preview (scaled to fit, arrows, Escape). Above the gallery, a lightweight screen-flow from `product/mockups/flow.md` or `flow.json` (nodes + edges). If neither file exists, infer a linear flow from the image filenames and label it inferred.

### Issues tab

Grouped rows scoped to this project. A `callout` line above them reads `Tracking only. Agents file and update these.` Clicking a row opens that issue's detail sheet. There is no jump to a studio Issues screen.

### Timeline tab

The same Gantt component as the master Timeline, scoped to this project — one project row, its milestones underneath, its dependency links, the same axis and the same `Week` / `Month` / `Quarter` control. Milestones are first-class. Completed issues appear as light ticks on the project bar. Click-through from the master view lands here. Read-only. Agents set milestones and dependencies through the API.

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
- **No milestone editing.** Timeline is read-only. No milestone form, no drag to reschedule a bar, and no way to draw or cut a dependency. Milestones and their `dependsOn` predecessors move only through the API.
- **No document editing.** `product/` is written in an editor and committed. Arkboard has no markdown text area outside the two composers, and no "save to product/" anywhere.
- **No MCP tool names in empty states.** An empty document does not teach the human to call `create_capability`. It says a director pass will write it, and stops.
- **No raw markdown in a reading view.**

The exception, deliberate and singular: **Archive** on an issue, with undo. Getting a stale row out of your reading view is hygiene, not management.

## Empty states

One shape everywhere: the section symbol in the hue at 40% — sized from the type scale at body + 15, so it is 28pt at the default 13pt body and grows with the Settings text size — a title in `heading`, one sentence in `callout` secondary. On the project home (Mockups, Design-not-written, Issues, Timeline, and the other document tabs) that block shares the document left edge — icon, title, and sentence leading, not a centred poster in the wash. Full-pane posters (no projects, Monitor, Activity) stay centred, with 40pt of air. No buttons unless the table says so.

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

## Chat with Chief of Staff

An AppKit / SwiftUI context menu on the entire app — sidebar, document, tabs, timeline rows, cards, onboarding, empty states. The label is exactly `Chat with Chief of Staff`. Not "Chief of Agent". Not a generic Chat.

Existing useful items stay. Pin / Unpin on a project row stay; this item is added. Issue rows keep `Copy identifier`, `Copy title`, and `Archive`. This menu does not offer status, priority, assignee, or issue creation. It does not open an external Grok chat. The board is the inbox.

Choosing the item (with a highlight or with none) opens that sheet. The title is exactly `Chat with Chief of Staff`. Do not title it Note.

- The composer is empty — placeholder `Tell the team…` only. Selection is silent context for Chief of Staff, not a message. Do not prefill the field with the highlight. The human writes the ask. If they copied, still prefer the current selection in the view over the clipboard for capture — just do not show it.
- One quiet friendly line for where they are, e.g. `Arkboard · Design · product/design.md`. Do not show a raw dump — no ISO timestamp, no `project · ARK · Design · …`, no destination jargon, no tab twice.

The Activity body is the comment they typed. Nothing else — no selected quote, no destination dump, no friendly page line in the body. The sheet chrome can still show the friendly line so they know where they are.

History is actor, time, and their comment. That is it.

Capture still knows these fields so Chief of Staff can read them via the engine / API / MCP. They live on the Activity row as `metadata` JSON — not rendered in History, not stuffed into markdown the human would see:

- **selected text**, if any
- **destination** — `portfolio` | `timeline` | `onboarding` | `project`
- **project key** and project name when a project is open
- current tab — Design / Architecture / Mockups / Decisions / Issues / Timeline
- current **document path** when a product doc is showing
- **nearest heading** if known
- a one-line "what this page is" (e.g. `Arkboard · Design · product/design.md`)
- **timestamp**

Sending persists via existing Activity as kind `handoff`, targeted at `Product` (Chief of Staff), actor `Riyu`. Do not invent a second store.

## Acceptance

The UI is done when all of these are true on a clean machine.

1. Launching from `./scripts/run.sh` restores the last sidebar row. The left sidebar is Portfolio, then Timeline, a hairline, then pinned projects — no Origin Ark row — and does not contain Monitor or Issues. Selecting a pinned project opens the document home (identity strip, six tabs, Design selected, markdown preview), not empty white.
2. The Arkboard row uses `square.3.layers.3d` in indigo, not a generic blue dot. A second project, if present, uses a different symbol.
3. The project home shows an identity strip (mark, key, source, refresh, note icon), six tabs, Design selected, and no article summary. The project's name appears once, in the window title bar, and nowhere else on the screen.
4. The Design, Architecture, and Decisions tabs each render this design pack as headings, prose, tables, lists, code blocks, and quotes. No `#` characters are visible as text.
5. The right column is labelled `Contents` and lists this page's headings. Clicking a heading scrolls the same document scroll to that subsection. There is no `On this page` chip rail.
6. Scrolling the project home moves the overview off screen and pins the tab bar; only one scrollbar is ever visible over the document. Contents overlays the document; it is not a split column that resizes the page.
7. Switching from Design to Architecture visibly changes the pane wash from rose to azure, and the Contents list updates to that document's headings.
8. Decisions & questions shows a gold chip for each `Open —` heading; clicking it jumps to that heading.
9. Settings changes the text size to 16 and the face to Georgia, and every screen — titles, chips, captions, document bodies, sidebar — follows. Relaunching keeps it.
10. Dark mode is legible on every screen, with no fixed light-mode colour left behind.
11. On Tahoe, built with Xcode 26, the sidebar is a floating pane of glass, the toolbar and the project tab rail are on glass, and Contents is edge-to-edge glass. The pane wash runs under the sidebar with no seam. The document body is solid on every screen. On macOS 14 and 15 the same surfaces resolve to that release's system materials and nothing looks hand-rolled.
12. Every filter — the six project tabs, the multi-document rail — is a system capsule with a system selected state. Right-clicking, hovering, and keyboard focus behave as they do in Finder and Mail, because they are the same controls.
13. No screen anywhere offers a status, priority, or assignee control, and no screen offers a way to create an issue.
14. An issue created through the API appears in the project's Issues tab without touching the app, and a note posted through the API is stored as Activity the same way.
15. Every empty state matches the copy in the table above.
16. No screen prints its own name in the pane. Portfolio opens on cards, Timeline on the chart, Onboarding on the document, a project on its identity strip. The window title bar is the only place a screen is named, and no screen carries a tagline under it.
17. A Portfolio card leads with the project's mark at hero size. The name, summary, paths, and document words are all quieter than that mark, and the sidebar beside the cards reads as a visibly different surface from the pane.
