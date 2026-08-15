# Design

Arkboard should feel like a studio notebook that happens to have an engine under it. Colourful, quiet, and legible at a glance. Not a grey ticket cockpit, not a dashboard, not a web page pretending to be a Mac app.

Three words to hold onto while building: **calm**, **coloured**, **continuous**. Calm means nothing blinks or nags. Coloured means every section has an identity you learn in a day. Continuous means one scroll per pane, no seams, no boxes inside boxes.

This document is the visual contract, and it is a living one: it describes the app that is on `main` today. If the chrome changes, this changes in the same pull request. A section here that describes something you cannot find in the running app is a bug in this file.

## What the app looks like

One window, two columns, and a title bar that names the page once.

**The left column is navigation** and it is short on purpose: **Portfolio**, **Timeline**, a hairline, then the projects you have pinned. That is the whole list. There is no workspace row, no Create button, no Monitor, no Issues, no Activity. The workspace name lives in the window subtitle. The column is system material — frosted, so it reads as a different surface from the document beside it — and the selected row is the system's *unemphasized* grey in every state, focused or not, so a project's mark and its key stay readable on the row that is selected.

**The right column is content** and it is solid, never glass. It opens directly on the thing you came for: Portfolio opens on cards, Timeline on the chart, Onboarding on the document, a project on its tab rail. Nothing prints a title band under the window's own title.

**Liquid Glass is the navigation layer and only the navigation layer** — the sidebar, the window toolbar, the project tab rail, the Contents inspector. A page of prose on glass cannot be read, which is the one mistake this split exists to prevent. On macOS 14 and 15 every one of those surfaces resolves to that release's system material; on Tahoe they become glass. There is no third, hand-rolled appearance.

### Portfolio is a wall of posters

Each project is a card led by its own picture — `product/card.png`, full-bleed to the card's rounded corners — with the project's name and one line of summary underneath, and nothing else. Checkout paths, the GitHub remote, and which documents exist are metadata about a project rather than a picture of one; they live on the project page, one click away. A project with no poster yet falls back to its mark, and then to a field in its own colour. Never a small chip beside a stack of fields.

### A project is six tabs and a document

`Design` · `Architecture` · `Mockups` · `Decisions & questions` · `Issues` · `Timeline`

Design is selected by default, because a project is a design object first. The rail is the first thing in the scroll, so it is pinned from the moment the page paints, and the mark and key sit in the window toolbar rather than in a row beneath it. Every tab starts its first line at the same Y under that rail — Design's prose, an empty state's title, the first row of a filled gallery — and switching tabs is instant. A tab that leads with something the others do not have moves the whole pane, and a body that moves is a jump a reader feels even when the rail is perfectly still.

A heading buys air above itself, which is right in the middle of a document and wrong at the top of one: there the pane's padding is already that air. The first block a tab renders never carries it, including the block that became first when a repeated opener was skipped.

The tabs are not symmetrical, and the origin has to survive that. When more than one document lands on a tab, a rail of document capsules sits above the prose — which today means Design (`design.md` and `ui-spec.md`) and Architecture (`architecture.md` and `mcp.md`), and no others. That rail is sized to its capsules, not to a horizontal scroll view, which would take more height than it holds and seat the tab's first line ~10pt below every tab without one.

**Contents** is a trailing overlay on edge-to-edge glass, not a third column. When it is open the prose reserves a gutter exactly as wide as it, so no glyph is ever printed underneath it.

**Chat with Chief of Staff** is a right-click, anywhere. It opens a compact sheet with a quiet line saying where you are, an empty field, and the project's history of notes. What sends is the note the human typed and nothing else — the page context is captured silently and never dumped into the body.

### Timeline is a Gantt

Rows are projects with their milestones underneath, bars run across one shared time axis, and dependency links join a milestone to the ones it waits on. Scale is `Week` / `Month` / `Quarter`, default Month, and the scale only decides how wide a gridline column is; the shape is always bars on a timeline, never a grid of dated cells. It is read-only for humans: agents set milestones and dependencies through the API.

## The ramp

The whole app is built from ten hues and a slate. Sections claim a hue, states borrow three of them, and agent avatars hash into the same set. Nothing outside this table is allowed to introduce a new colour.

| Hue | Light | Dark |
| --- | --- | --- |
| rose | `#D4436B` | `#F27897` |
| ember | `#C2661F` | `#F0975A` |
| gold | `#A87908` | `#E0B94A` |
| moss | `#1F8F63` | `#4FC694` |
| teal | `#12908C` | `#3FC3BC` |
| azure | `#2C6FCF` | `#69A3F2` |
| indigo | `#5A62D6` | `#8D93F2` |
| violet | `#8A54D6` | `#B389F0` |
| magenta | `#B23FA8` | `#DC79D0` |
| crimson | `#C0392B` | `#F2776A` |
| slate | `#6E7781` | `#9AA4AF` |

Each hue resolves through one function that reads the current `ColorScheme`. There is no third variant and no opacity baked into the hex.

### Sections claim a hue

Section identity is the point of the colour system: you should know which tab you are on from the corner of your eye.

| Section | Hue | SF Symbol | Where it appears today |
| --- | --- | --- | --- |
| Portfolio | violet | `square.grid.2x2` | sidebar destination, card grid |
| Timeline | moss | `chart.bar.xaxis` | sidebar destination, Gantt |
| Design | rose | `paintpalette` | project tab |
| Architecture | azure | `square.stack.3d.up` | project tab |
| Mockups | magenta | `photo.on.rectangle.angled` | project tab |
| Decisions & questions | gold | `questionmark.bubble` | project tab |
| Issues | teal | `tray.full` | project tab, issue groups |
| Onboarding | indigo | `sparkles` | sidebar footer |

Monitor (indigo, `binoculars`) and Activity (ember, `bubble.left.and.bubble.right`) keep their hues in the palette because the engine behind them is real and agents read it. **Neither is a destination.** They are not rows in the left column, and a section entry here is not a licence to add one. Monitor's output surfaces as the gold question chips above the Decisions tab; the agent server's health is the dot in the sidebar footer and the Agents section of Settings.

Design's rose and Architecture's azure sit two tabs apart and must never be confused; if they ever look similar on screen, the wash is too weak, not the hue wrong.

### States borrow three

| State | Hue | Where it shows |
| --- | --- | --- |
| Working, done, shipped | moss | capability health, milestone done, completed ticks on a project bar |
| Underway, due soon | gold | capability being implemented, milestone in progress |
| Not working, missed | crimson | broken capabilities, missed milestones |
| Unknown, queued, archived | slate | unassessed capabilities, queued issues |

### Agents borrow the rest

Actor colour is a pure function of the actor's lowercased name. Four names are reserved so the studio's regulars are stable; everything else hashes across the ten hues.

- `riyu` → moss (the human is the steady one)
- `agent` → azure
- `cursor` → violet
- `grok` → ember
- anything else → `hues[hash % 10]`, computed with FNV-1a over UTF-8 bytes, not Swift's per-launch `hashValue`

A teammate's avatar changing colour between launches is a bug.

## Surfaces

Neutrals come from AppKit semantic colours so light and dark, increased contrast, and accessibility settings work without a second palette.

| Token | Value |
| --- | --- |
| Document field | `NSColor.windowBackgroundColor` |
| Card / raised surface | `NSColor.controlBackgroundColor` |
| Text field / editor surface | `NSColor.textBackgroundColor` |
| Hairline | `NSColor.separatorColor` |
| Primary text | `NSColor.labelColor` |
| Secondary text | `NSColor.secondaryLabelColor` |
| Tertiary text | `NSColor.tertiaryLabelColor` |
| Selected sidebar row | `NSColor.unemphasizedSelectedContentBackgroundColor` |

The document field belongs to the document alone. Painting it on a navigation surface is what blocks the glass, so the sidebar, the tab rail, the toolbar and the Contents inspector take the system's material and nothing else. The selected-row grey is not a colour we paint either: AppKit chooses the emphasized or unemphasized style from first-responder status, so the sidebar keeps its list from taking first responder — the same thing Finder, Mail and Music do — and the row keeps the system's own quiet rendering.

Section colour arrives only as tint on top of those neutrals, never as a replacement:

| Element | Light | Dark |
| --- | --- | --- |
| Pane wash | hue at 6% over the document field | hue at 10% |
| Card stroke | hue at 14% | hue at 20% |
| Chip / pill fill | hue at 12% | hue at 18% |
| Chip / pill text and icon | hue at 100% | hue at 100% |
| Divider under a rule | hue at 22% | hue at 30% |
| Selected tab capsule | the system's selected state, tinted with the section hue | same |

> Running prose is never tinted. Body copy is `labelColor`, secondary copy is `secondaryLabelColor`, and that is the end of it. Colour lives in washes, chips, dots, icons, and rules — the things you see without reading.

Elevation is one shadow, used on floating things only (sheets, popovers, the undo toast): `black` at 18% light / 45% dark, radius 12, y-offset 4. Cards do not have shadows. Cards have a 1pt stroke and a solid fill.

## Type

Body text is **13pt** by default. That is the studio's reading size and it is what ships.

Settings can move the whole app to 12, 14, or 16, and can change the face. Both choices apply from the root of the view tree and persist. Every piece of text in the app derives from the body size — there are no hard-coded `.title2` or `.caption` calls anywhere, because that was the previous build's most visible bug: half the chrome ignored the setting.

### The scale

With body size `B`:

| Role | Size | Weight | Used for |
| --- | --- | --- | --- |
| `display` | `B + 10` | semibold | document `#`, issue titles |
| `title` | `B + 6` | semibold | document `##`, sheet titles |
| `heading` | `B + 3` | semibold | card titles, group headers, empty-state titles, document `###` |
| `subheading` | `B + 1` | medium | document `####`–`######` |
| `body` | `B` | regular | prose, list items, quotes, tab labels, sidebar rows |
| `bodyStrong` | `B` | medium | emphasised lines, chip labels at body size |
| `callout` | `B − 1` | regular | secondary lines under a title, card summaries |
| `caption` | `max(10, B − 2)` | medium | timestamps, counts, metadata, chips |
| `mono` | `B − 1` | regular, monospaced | identifiers, code, paths, endpoints |

`mono` always uses the monospaced design regardless of the chosen face — an issue identifier and a shell command should stay aligned even when the studio is reading in Georgia.

**One exception, and only one.** A project mark is a product icon, not type: its corner and its glyph are fractions of its tile off the icon grid, which is why the same view reads correctly at 22pt in the sidebar and at poster size on a card. Nothing else in the app sizes itself outside the scale, and `.font(.system(size:))` does not appear anywhere a human reads.

### The faces

Eight real macOS faces, no downloads:

| Setting label | Implementation |
| --- | --- |
| System (SF Pro) | `.system(size:weight:design: .default)` |
| New York | `.system(size:weight:design: .serif)` |
| SF Rounded | `.system(size:weight:design: .rounded)` |
| SF Mono | `.system(size:weight:design: .monospaced)` |
| Helvetica Neue | `Font.custom("Helvetica Neue", size:)` |
| Georgia | `Font.custom("Georgia", size:)` |
| Avenir Next | `Font.custom("Avenir Next", size:)` |
| Menlo | `Font.custom("Menlo", size:)` |

### Rhythm

- Prose line spacing is `max(3, round(B * 0.3))` — 4pt at the default size.
- The gap between two markdown blocks equals the body size: 13pt at 13pt, 16pt at 16pt.
- Headings get extra air above, never below: `B` for `#` and `##`, `B / 2` for deeper levels.
- Reading columns fill the pane and left-align, with pane padding only. No 720-centred island, and no 1000pt grid cap — a document, a card grid, and the Timeline all take the room the window gives them.
- Section headers in lists and tables are title case. `Underway`, never `UNDERWAY`.

## Space and shape

Spacing comes from one scale: **2, 4, 8, 12, 16, 20, 24, 32, 40**. If a number outside that list appears in a layout, it is a mistake.

| Metric | Value |
| --- | --- |
| Pane padding | 24 horizontal, 20 vertical |
| Card padding | 14 |
| Chip padding | 10 horizontal, 4 vertical |
| Gap between cards | 12 |
| Gap between sections in a pane | 28 |
| Sidebar width | 232 ideal, 200 min, 300 max |
| Air above and below a sidebar row | 5 |
| Document column | fills the pane, 560 min |
| Contents overlay | 220 ideal, 180 min, 280 max |
| Portfolio card | 320–480 wide, poster at 3:2 |
| Minimum window | 1080 × 700 |
| Default window | 1320 × 860 |

Corner radii are one family, continuous style everywhere. A surface nested inside another takes its container's radius less the inset between them, so the two curves share a centre, and the radii are derived in `Metrics` rather than typed in at each call site.

| Radius | Applied to |
| --- | --- |
| 14 | sheets, popovers, floating toast |
| 10 | cards, code blocks, images, composer |
| 6 | chips and inline badges, derived from the card radius |
| tile × 0.2237 | project marks, at any size, off the icon grid |
| capsule | tab capsules, actor chips, identifiers, counts |

Icons are SF Symbols at `body` size unless stated, rendered in the section hue. No emoji anywhere in the chrome.

## Scroll

**One scrollable content region per pane.** This is the rule that most changes how the app feels, so it is worth stating precisely:

1. A pane may have fixed chrome — the window toolbar, a filter row. Fixed chrome does not count as a scroll region.
2. Below the chrome there is exactly one vertical `ScrollView`, and everything the pane has to say lives inside it.
3. A `List` is never placed inside a `ScrollView`. Where a pane needs rows, use a `LazyVStack` of row views inside the single scroll.
4. Horizontal scrolling inside the vertical scroll is allowed, because the axes do not fight: the tab rail uses it. The outline is the right-hand **Contents** overlay, not a chip row in this scroll.
5. Sticky headers come from `LazyVStack(pinnedViews: .sectionHeaders)` within that single scroll, not from a second container.

The project page is the case that proves the rule. The tab rail is the first thing in that scroll, so it pins from first paint with nothing above it that can push it around, and the document continues underneath. Headings are listed in the right Contents overlay and jump this same scroll. They are not a second copy of the document, and they are not a third `NavigationSplitView` column — that collapsed the page to empty white.

**Nothing animates the pane's geometry on a tab change.** An eased height change plus a programmatic scroll is what made the pane bounce, and easing the assignment in a binding is the same mistake wearing a different hat. The scroll returns to the top of the tab body — every tab, the same way, unanimated — and the anchor is never the pinned rail, because a pinned view is being repositioned by the scroll view itself and scrolling *to* it chases a moving target. Jumping from the outline animates over 0.2s. When **Reduce Motion** is on, that becomes instant too.

## Reading markdown

Documents are the product, so the renderer is a first-class surface, not a convenience. It parses markdown into blocks and renders each block as native SwiftUI. Users never see raw markup in a reading view.

**One headline.** The window title bar names the page and the tab rail names the section, so a document that opens with an H1 saying the same thing is a second headline: that heading is not rendered and does not appear in Contents. The file on disk is never edited to achieve this, and a document with a title of its own keeps it.

### Blocks that must render

| Block | Rendering |
| --- | --- |
| `#`–`######` | scale roles `display` / `title` / `heading` / `subheading`, air above |
| Paragraph | `body`, selectable, full pane width |
| Bullet list | hanging bullet in the section hue, 18pt marker column, 6pt between items |
| Ordered list | hanging number in `mono`, right-aligned in the marker column |
| Nested list | one level of nesting, indented 20pt |
| Fenced code | `mono` on `textBackgroundColor`, radius 10, 12pt padding, 1pt hue stroke at 18%, language name in `caption` in the top-right corner, horizontally scrollable, copy button on hover |
| Inline code | `mono`, hue-tinted fill at 10%, radius 6, 3pt horizontal padding |
| Block quote | 3pt hue bar on the left, 12pt inset, secondary text |
| Table | header row in `bodyStrong` on hue at 8%, hairline row separators, cells padded 8×6, whole table horizontally scrollable when wide |
| Horizontal rule | 1pt hairline, 12pt air above and below |
| Image | radius 10, max height 420, scaled to fit, caption from alt text in `caption` below |
| Link | hue-coloured, underlined on hover |

Bold, italic, strikethrough, and inline code inside paragraphs, list items, quotes, and table cells all work. Task lists, footnotes, and raw HTML are out of scope — if a document needs them, the document is wrong.

### Links behave like a Mac app

- `http` and `https` open in the default browser.
- A relative link to another document in the same `product/` folder — `[design.md](design.md)` — switches to the tab that document belongs to instead of opening anything.
- A link to a heading anchor within the current document scrolls to it.
- Image paths resolve against the document's own folder first, then the repo root, then the network.

### Outline

Any document with two or more headings fills the right-hand **Contents** column:

- The heading `Contents` in `caption`.
- Every heading on the current page, indented by level, which is the complete outline and works for a document with two headings or two hundred.
- Clicking a row scrolls the document to that heading with the heading landing at the top of the visible area.

This is the only outline. Do not also pin an `On this page` menu or a chip rail under the tab rail, and do not put contents on the left. The right column is navigation; the document column is the only scroll of the prose.

### When a document is not there

Every empty document state is the same shape: the section symbol on the title's own line, a short title, one sentence of explanation, and nothing else. No buttons. No tool names. No instructions to run anything. The symbol rides inline at the title's size rather than as a row above it, because a row above the title would push the whole pane down and break the origin every tab shares. A centred full-pane poster — no projects at all — is the one place the symbol still leads at 28pt, because it has no rail to line up under. The exact copy is in [ui-spec.md](ui-spec.md).

> A director pass writes the documents. The app's job when a document is missing is to be quiet about it.

## Appearance

Light, Dark, and System, chosen in Settings and persisted. Light is the default because the studio reads in daylight and the washes were tuned there. Dark is not an afterthought: every hue in the ramp has a dark value, washes double in opacity, and the shadow deepens. Test both before calling anything finished.

## The taste tests

If you are unsure whether something belongs, these are the questions.

1. **Can Riyu tell which section they are in with the window at the edge of their vision?** If not, the wash or the header is too weak.
2. **Does the pane scroll as one thing?** If two scrollbars can appear side by side over the same content, it is wrong.
3. **Does it survive 16pt Georgia?** Every layout must hold at the largest size and the widest face. Fixed-height rows that clip descenders are the usual failure.
4. **Would a ticket tracker have shipped this control?** If the answer is yes — a status dropdown, a priority flag, an assignee avatar picker, a swimlane — it does not go in the human UI.
5. **Is there any raw markdown on screen outside an editor?** Then the renderer has a gap; fill it.
6. **Does the click measure the same as the still?** A screenshot cannot show a body that moves under a rail that does not. If a change has not been measured on the Mac, it has not been reviewed.
