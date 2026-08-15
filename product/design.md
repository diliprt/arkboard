# Design

Arkboard should feel like a studio notebook that happens to have an engine under it. Colorful, quiet, and legible at a glance. Not a grey ticket cockpit, not a dashboard, not a web page pretending to be a Mac app.

Three words to hold onto while building: **calm**, **coloured**, **continuous**. Calm means nothing blinks or nags. Coloured means every section has an identity you learn in a day. Continuous means one scroll per pane, no seams, no boxes inside boxes.

This document is the visual contract. Numbers here are the numbers to type.

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

| Section | Hue | SF Symbol |
| --- | --- | --- |
| Monitor | indigo | `binoculars` |
| Issues | teal | `tray.full` |
| Activity | ember | `bubble.left.and.bubble.right` |
| Portfolio | violet | `square.grid.2x2` |
| Design | rose | `paintpalette` |
| Architecture | azure | `square.stack.3d.up` |
| Mockups | magenta | `photo.on.rectangle.angled` |
| Decisions & questions | gold | `questionmark.bubble` |
| Timeline | moss | `calendar` |

The project overview header claims **no section hue**. It carries the project's persisted mark — SF Symbol plus brand colour, or an image from `product/` — and nothing else, so the header never competes with the tab body underneath it. Design's rose and Architecture's azure sit two tabs apart and must never be confused; if they ever look similar on screen, the wash is too weak, not the hue wrong.

### States borrow three

| State | Hue | Where it shows |
| --- | --- | --- |
| Working, done, shipped | moss | capability health, milestone done, timeline dots |
| Underway, due soon | gold | capability being implemented, milestone in progress |
| Not working, missed | crimson | Monitor's broken lane, missed milestones |
| Unknown, queued, archived | slate | unassessed capabilities, queued issues |

### Agents borrow the rest

Actor colour is a pure function of the actor's lowercased name. Four names are reserved so the studio's regulars are stable; everything else hashes across the ten hues.

- `riyu` → moss (the human is the steady one)
- `agent` → azure
- `cursor` → violet
- `grok` → ember
- anything else → `hues[abs(name.hashValue) % 10]`, computed from a stable string hash, not Swift's per-launch `hashValue`

Use a small deterministic hash (FNV-1a over UTF-8 bytes). A teammate's avatar changing colour between launches is a bug.

## Surfaces

Neutrals come from AppKit semantic colours so light and dark, increased contrast, and accessibility settings work without a second palette.

| Token | Value |
| --- | --- |
| Window background | `NSColor.windowBackgroundColor` |
| Card / raised surface | `NSColor.controlBackgroundColor` |
| Text field / editor surface | `NSColor.textBackgroundColor` |
| Hairline | `NSColor.separatorColor` |
| Primary text | `NSColor.labelColor` |
| Secondary text | `NSColor.secondaryLabelColor` |
| Tertiary text | `NSColor.tertiaryLabelColor` |

Section colour arrives only as tint on top of those neutrals, never as a replacement:

| Element | Light | Dark |
| --- | --- | --- |
| Pane wash | hue at 6% over window background | hue at 10% |
| Card stroke | hue at 14% | hue at 20% |
| Chip / pill fill | hue at 12% | hue at 18% |
| Chip / pill text and icon | hue at 100% | hue at 100% |
| Selected tab pill fill | hue at 16% | hue at 24% |
| Divider under a section header | hue at 22% | hue at 30% |

> Running prose is never tinted. Body copy is `labelColor`, secondary copy is `secondaryLabelColor`, and that is the end of it. Colour lives in washes, chips, dots, icons, and rules — the things you see without reading.

Elevation is one shadow, used on floating things only (sheets, popovers, the undo toast): `black` at 18% light / 45% dark, radius 12, y-offset 4. Cards do not have shadows. Cards have a 1pt stroke and a wash.

## Type

Body text is **13pt** by default. That is the studio's reading size and it is what ships.

Settings can move the whole app to 12, 14, or 16, and can change the face. Both choices apply from the root of the view tree and persist. Every piece of text in the app derives from the body size — there are no hard-coded `.title2` or `.caption` calls anywhere, because that was the previous build's most visible bug: half the chrome ignored the setting.

### The scale

With body size `B`:

| Role | Size | Weight | Used for |
| --- | --- | --- | --- |
| `display` | `B + 10` | semibold | document `#`, project name in the overview header |
| `title` | `B + 6` | semibold | screen titles, document `##` |
| `heading` | `B + 3` | semibold | card titles, group headers, document `###` |
| `subheading` | `B + 1` | medium | document `####`–`######`, lane labels |
| `body` | `B` | regular | prose, list items, quotes |
| `bodyStrong` | `B` | medium | emphasised lines, chip labels at body size |
| `callout` | `B − 1` | regular | secondary lines under a title |
| `caption` | `max(10, B − 2)` | medium | timestamps, counts, metadata, chips |
| `mono` | `B − 1` | regular, monospaced | identifiers, code, paths, endpoints |

`mono` always uses the monospaced design regardless of the chosen face — an issue identifier and a shell command should stay aligned even when the studio is reading in Georgia.

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
- A prose column is capped at **720pt** and centred. Grids, timelines, and feeds cap at **1000pt**.

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
| Document column | 720 ideal, 560 min |
| Contents column | 220 ideal, 180 min, 280 max |
| Issues list column | 420 ideal, 340 min, 620 max |
| Minimum window | 1080 × 700 |
| Default window | 1320 × 860 |

Corner radii, continuous style everywhere:

| Radius | Applied to |
| --- | --- |
| 6 | small chips, inline badges, colour dots on rects |
| 10 | cards, code blocks, images, composer |
| 14 | sheets, popovers, floating toast |
| capsule | tab pills, actor chips, identifiers, counts |

Icons are SF Symbols at `body` size unless stated, rendered in the section hue, `.medium` weight. No emoji anywhere in the chrome.

## Scroll

**One scrollable content region per pane.** This is the rule that most changes how the app feels, so it is worth stating precisely:

1. A pane may have fixed chrome — a screen title bar, a filter row, a toolbar. Fixed chrome does not count as a scroll region.
2. Below the chrome there is exactly one vertical `ScrollView`, and everything the pane has to say lives inside it.
3. A `List` is never placed inside a `ScrollView`. Where a pane needs rows, use a `LazyVStack` of row views inside the single scroll.
4. Horizontal scrolling inside the vertical scroll is allowed, because the axes do not fight: the tab bar uses it. The outline is a separate right-hand column, not a chip row in this scroll.
5. Sticky headers come from `LazyVStack(pinnedViews: .sectionHeaders)` within that single scroll, not from a second container.

The project home is the case that proves the rule. Overview, tab bar, and document all live in one scroll: the overview scrolls away, the tab bar pins to the top when it reaches it, and the document continues underneath. It reads like a repository page, because that is the right mental model for a project that is mostly documents. Headings are listed in the right Contents pane beside that scroll; they jump this same scroll. They are not a second copy of the document, and they are not a third `NavigationSplitView` column — that collapsed the page.

Switching tabs animates the pane content with a 0.18s ease-in-out cross-fade and returns the scroll to the top. Jumping from the outline animates the scroll over 0.2s. When **Reduce Motion** is on, both become instant.

## Reading markdown

Documents are the product, so the renderer is a first-class surface, not a convenience. It parses markdown into blocks and renders each block as native SwiftUI. Users never see raw markup in a reading view.

### Blocks that must render

| Block | Rendering |
| --- | --- |
| `#`–`######` | scale roles `display` / `title` / `heading` / `subheading`, air above |
| Paragraph | `body`, selectable, 720pt column |
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
- Clicking a row scrolls the document column to that heading with the heading landing at the top of the visible area.

This is the only outline. Do not also pin an `On this page` menu or a chip rail under the tab bar, and do not put contents on the left. The right column is navigation; the document column is the only scroll of the prose.

### When a document is not there

Every empty document state is the same shape: a large section symbol at 28pt in the hue at 40%, a short title, one sentence of explanation, and nothing else. No buttons. No tool names. No instructions to run anything. The exact copy is in [ui-spec.md](ui-spec.md).

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
