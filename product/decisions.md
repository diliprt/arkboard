# Decisions & questions

What is settled, and what is still open. This file is the source of truth for both. A note typed into the app is a sticky; this is the record.

The headings here are load-bearing. Arkboard parses this document to build the open-questions lane, and the rule is simple: a heading starting with **Locked** or **Decided** is settled, and a heading starting with **Open** or ending in a question mark is not. Keep the convention when you add to this file, and the parse stays honest for free.

> **Supersede, 2026-08-15.** Older locks below name Monitor as a screen. It is not one and has not been for several passes: the engine is real, but it has no sidebar row and no destination, and its questions surface as the gold chips above a project's Decisions tab. The locks themselves still hold; only the screen name is stale. Nothing here licenses adding Monitor, Issues or Activity back to the left column.

## Locked — `product/` in Git is the source of truth

Design, architecture, mockups, and decisions are files in the repository. Arkboard reads them and renders them. It does not copy them into SQLite, does not cache their text in a table, and offers no way to edit them.

The database holds what documents cannot hold: what has happened. Issues, comments, activity, milestones, capability health. That is the entire split, and every architectural question resolves against it.

> A missing `product/` folder is a calm empty state, not a prompt. "A director pass will write this." No wizard, no button, no MCP tool name.

## Locked — The human UI has no status, priority, or assignee

Riyu does not groom a backlog and does not assign work. So there is no status dropdown, no priority flag, no assignee picker, and no board to drag cards across. Those fields exist in the database because agents need them; they never surface as controls.

Humans see three groups — Underway, Queued, Done — and the group is the only status indication on screen. No pills on rows.

## Locked — Saying something is the intake

There is no New Issue button and no `⌘⇧N`. If Riyu wants something to happen, they type it into the project composer, it lands in Activity attributed to them, and an agent files the issue.

This is the product thesis expressed as a missing button. Adding a quick-add form would quietly turn Arkboard back into a tracker with a reading room bolted on.

## Locked — Archive with undo is the one exception

Humans can archive an issue, from the row's context menu or the detail toolbar, with a ten-second undo toast. Archiving is reading hygiene — getting a stale row out of your view — not work management. It is the only mutation a human can make to an issue besides commenting.

## Locked — One scroll per pane

Fixed chrome above, exactly one vertical scroll below, and never a `List` inside a `ScrollView`. Rows are a `LazyVStack`. Sticky headers come from pinned section headers in that same scroll. Horizontal scrolling within it is fine, because the axes do not fight.

The project home is the proof: overview, tab bar, and document are one scroll, the overview scrolls away, and the tab bar pins. It reads like a repository page, which is the right model for a project that is mostly documents.

## Locked — The outline is the right Contents column

Long documents list every heading in a right-hand Contents pane. Clicking a heading jumps the document scroll to that subsection. There is one outline, and it is on the right — not a left rail, not a pinned `On this page` chip bar under the tabs. A left rail that is its own scroll of the document is still wrong; Contents is navigation, not a second copy of the page.

## Locked — The left sidebar is Portfolio, Timeline, then pins

Portfolio is a destination. Timeline is a destination. A hairline separates those two rows from pinned projects below. The workspace name lives in the window subtitle — no Origin Ark icon or row in the sidebar. Create lives on the Portfolio page, not in the left chrome. Monitor, Issues, and Activity are not sidebar rows. Existing projects start pinned. Unpinning removes a row from the sidebar and leaves the project on the Portfolio page and in Settings.

## Locked — Timeline is a Gantt, not a calendar

The canned calendar grid is not the Timeline. A month of dated cells answers "what is on the 14th", which nobody asked; the studio needs to see broader projects, their overall timelines, and what blocks what. So the master Timeline is a Smartsheet-style project plan: rows are projects, milestones nest under them, bars run across one time axis, and dependency links join a milestone to the ones it waits on. Clicking a project row opens that project's Timeline tab, which is the same component scoped to one project.

`Week` / `Month` / `Quarter` survive as *scale* — the width of a gridline column — with Month the default. They no longer change the shape of the view. Year is dropped: one column per year is not a plan.

> **Supersede, 2026-08-16.** Scale is `Week` / `Month` / `Year`. Quarter is gone. Year is a coarser axis, not a dropped scale. The Gantt shape is unchanged and still read-only.

Milestones stay in SQLite; there is no second timeline store. Dependencies are one new column, `milestone.dependsOn`, a JSON array of predecessor milestone ids added in `v5-milestone-dependencies`. A milestone still holds one date, so its bar runs from its latest predecessor's target — or its project's start — to its own target. Agents write `dependsOn` through `create_milestone` / `update_milestone`; missing ids, self-references, and cycles are rejected. Humans read the links and never edit a milestone, a status, or a dependency.

## Locked — The project home is a thin header

No README article and no large composer sit above the tabs. The long description lives on the Portfolio card. Feedback is a compact icon that opens a note plus Activity history. `⌘N` focuses that sheet.

## Locked — Chat with Chief of Staff is the board inbox

Right-click anywhere — sidebar, document, tabs, timeline rows, cards, onboarding, empty states — offers `Chat with Chief of Staff`. That item opens the compact note sheet empty — placeholder only — with a quiet friendly page line in the chrome. Selection is silent context for Chief of Staff, not a message; the human writes the ask. Sending writes a `handoff` Activity to `Product` through `post_note`. The Activity body is the typed comment only. Selection, page, tab, doc, and heading live in `metadata` JSON that History does not print. The board is the inbox. Do not open an external chat.

## Locked — Apple language, not Apple content

Arkboard borrows how Apple's design team builds a Mac app. It borrows nothing else. No Apple Music screens, no playlists, no album art, no lifted copy, no branding. What we take is the grammar: system materials, system controls, one type scale, concentric corners, content edge to edge with navigation floating above it.

The dividing line is Liquid Glass, and it is the whole rule. Glass is the **navigation** layer — sidebar, window toolbar, project tab rail, Contents inspector. The document is the **content** layer and stays solid, because prose on glass cannot be read. If a surface is asking "where am I / show me something else", it is glass; if it is the thing you came to read, it is not.

The practical consequence is subtraction, not addition. Custom backgrounds behind navigation surfaces sit on top of the system material and block it, so the fix for a sidebar that will not look like a sidebar is to delete the paint, not to mix a better colour. Filters are native accessory-bar capsules with the section hue as their tint, not hand-drawn pills; the shape, hover, and selected state come from the system and therefore match Finder and Mail for free.

> Deployment stays at macOS 14. Every Tahoe API sits behind an availability check with a system-material fallback, so the app has two appearances — this release's materials and Liquid Glass — and never a third one of our own invention.

This lock still holds, and the three that follow are what it means in practice.

## Locked — The window title is the only title

The title bar carries the screen's name and the workspace subtitle. Nothing in the pane below repeats either one.

Every screen used to open with the same band: a section symbol, a large title, a one-line tagline, a hue rule. The result was the word "Arkboard" twice on top of itself, and the top of every pane spent on saying where you already knew you were. That band is void, and so is the `ScreenHeader` view that drew it. Portfolio opens on cards, Timeline on the chart, Onboarding on the document, and a project on a compact identity strip that carries the mark, the key, the source, and the two actions — never the name again.

Page actions go in the window toolbar, on toolbar glass. A filter or a scale control may sit as a quiet native control at the top of the content it governs, beside the thing it changes. Neither is a headline, and neither earns a band.

> If a screen ever needs a caption to explain what it is, the screen is wrong. Fix the screen.

## Locked — The Portfolio card is the picture

Every project gets a generated poster committed at `product/card.png`, and that image is the card face: full-bleed to the card's rounded corners, with the project name and one line of summary underneath. Nothing else is on the tile.

Checkout paths, the GitHub remote, and the four document words are gone from it. They are metadata about a project, not a picture of one, and they are one click away on the project page. A card that lists them is a form; Riyu compared ours to a wall of posters and ours was a wall of forms.

Resolution order is `card.png`, then the small mark (`icon.png` / `mark.png` / `logo.png`), then a field in the project's own colour carrying its SF mark. The last is a placeholder that still looks designed — a project with no artwork yet never falls back to a chip beside a metadata stack. The sidebar keeps using the small mark at 22pt; a poster does not read at that size.

Brand artwork lives at the root of `product/` and is routed out of the Mockups gallery. It is the project's own face, not a frame a director drew.

> The summary is the first sentence of `product/README.md` with the project's name stripped off the front — and the copula it strands stripped with it. `Arkboard is Origin Ark Studio's board` becomes `Origin Ark Studio's board`. A card line never opens mid-sentence.

## Locked — One headline

The window title bar names the page. The tab rail names the section. Nothing else may name either one again.

That means a document whose first heading repeats the title it sits under does not render that heading, and does not list it in Contents. `# Design` under the Design tab is a second headline; `# UI specification` under the Design tab is a document title and stays. The markdown file is never edited to achieve this — the reader skips the repeated opener, and the file on disk is still the file on disk.

It also means the project page has no identity strip. Mark and key sit in the toolbar beside the window title, and the pane starts at the tab rail. A mark-plus-key row under a title bar that already says `Arkboard` is a second logo row.

And it means **Timeline has no in-page title**: that pane opens on the scale control and the Gantt. The window title bar is also pinned to the inline display mode, because a title and subtitle stacked in their own row under a sparse toolbar reads as a headline band even when no view is drawing one — which is what Timeline looked like while its code had no band at all.

## Locked — product/ tabs are living

Design, Architecture, Mockups and Decisions describe the app that is on `main`. They ship **in the same pull request as the chrome they describe**, not in a brochure pass afterwards.

A tab that still describes dead chrome is a defect, and it fails review the same way a broken layout does. This is not pedantry about documentation: `product/` is what Arkboard renders. A stale Design tab is a stale *screen in the running app*, read by the person who has to trust it, and by every agent that reads the pack to find out what it is building. We shipped Portfolio posters, a grey selected row, one window title and a Gantt while `product/design.md` still mapped Monitor, Issues and Activity as the left sidebar. Anyone reading the app to learn the app was being told a version of it that had not existed for weeks.

The rule in practice:

- Change the chrome, change the tab, one PR. If the diff touches `Sources/Arkboard/UI/` and the behaviour it describes is written down, the writing moves too.
- **Mockups are the latest measured window shots** in `product/mockups/`, taken from the current build. Not a folder someone forgot. An empty gallery is honest; a gallery of last month's chrome is not.
- Never rewrite a historical lock to pretend it always said the current thing. Add a supersede line and leave the record intact — the reasoning is the point of this file, and reasoning that has been quietly edited is worth nothing.
- Critique and merge fail if a tab still describes something you cannot find in the running app.

> A design pack that lags the product is worse than no design pack, because people believe it.

## Locked — Mac-first measures before Critique

Critique reviews a shot set that already carries Mac numbers. **A still without the click measures is not a review**, and asking for one is asking someone to guess.

This rule exists because we spent four passes on a jump that no screenshot could show. The rail was photographed sitting still at 93pt on Design, on Mockups, and on Design again — and it was still wrong, because the body under it dropped from 197 to 249. Fifty-two points of text moved and every still said the layout was fine. Nobody feels a rail. Score the click.

**The visual contract, written before the PR, not discovered after it.** Every screen states:

- **Content origin** — the Y of the first line under the tab rail, and that sibling tabs share it.
- **Selected row** — its colour *while the sidebar has focus*, and that the mark, name and key stay readable rather than being forced white. Unfocused grey proves nothing; the bug only appears when the list is key.
- **One title row** — the window title and subtitle, with no in-page heading repeating either.

**The order is fixed:**

1. Spec and `spec_check` lock the intended behaviour.
2. Implement it.
3. Apple Build compiles on the existing Mac checkout — no worktrees — and runs `./scripts/mac_measure.sh` against the running Debug build.
4. The numbers drift, the build fails. Exit 1 is not a discussion.
5. Only then does Critique see it.

The measure script lives in the repo at `scripts/mac_measure.swift`. Throwaway helpers under `build/` are scratch work, never the source of truth: a check nobody can read or review is not a check. If the repo script is missing something, the fix is a PR against the repo script.

**What the script samples, and why.** The selection check presses a **pinned project row**, never the first row in the list. The mark floor asks whether a *project's* mark keeps its colour on a selected row; Portfolio and Timeline are section symbols at the size of a line of text, so sampling one of those measures the wrong thing and fails an app that is behaving. Do not lower the floor to make a destination row pass — press a project instead.

The mark is sampled **from its own accessibility frame**, pulled well inside it, not from a fixed offset into the row. A guessed rectangle lands in the padding beside the icon and reports a colour failure for an app that is fine; that is how a saturation of 0.037 was read off a mark measuring about 0.14. The fill is sampled between the mark and the key so neither is in it, and the report prints both sample rectangles and the row it pressed, so a bad number can be told from a bad sample without another run. If the captured bitmap does not line up with the window bounds, the capture refuses to report rather than sampling the wrong pixels.

There is **one measure path**. `scripts/mac_measure.swift` is it. Helpers under `build/` are scratch: when the SDK moves under the script — `CGWindowListCreateImage` is unavailable in the macOS 26 SDK, so the capture shells out to `screencapture` for one window — the fix lands in the repo script, in a PR, where it can be read. A second measure path means two answers and no way to tell which is true.

> Known numbers, so this lock has teeth. Rail Y **93 / 93 / 93** across Design → Mockups → Design has been correct throughout, and body Y is what keeps failing: **197 → 249** in the first pass, **145 / 134 / 145** in the second. Body Y must match across sibling tabs within 2pt. Do not add pixel numbers to this record that nobody measured, and do not loosen the tolerance to make a drift pass.

## Locked — Every project tab shares one content origin

The first line of a tab body starts at the same Y under the rail on every tab. Design's prose, an empty state's title, the first row of a filled gallery: all of them begin at the pane's vertical padding, with nothing above them.

We fixed the rail three times before understanding that a still rail is not a still pane. Measured on the click, the rail held at 93pt through Design → Mockups → Design while the body dropped from 197 to 249. Nobody feels a rail; they feel 52pt of text moving. **Score the click, not the rail.**

The 52pt was the Mockups empty state opening with a 28pt section symbol above its title — a row Design's prose has no equivalent of. Section identity now rides inline on the title's own line at the title's own size, so it adds no height above it. A centred full-pane poster keeps the big symbol, because it has no rail to line up under.

Two things have broken this, and both were invisible in a still:

1. **A decoration row above the first line.** The Mockups empty state opened with a 28pt section symbol. Moving that symbol inline onto the title's line closed the 52pt, but left about ten, because a baseline-aligned row containing a symbol sizes itself to share a text baseline and lifts the row's top above where a plain line of prose starts. A document empty state now opens on one top-aligned `Text`, laid out the way a paragraph is laid out — no symbol beside it, same line spacing. The pane already carries the section's hue; the title does not need to repeat it.
2. **Air the first block should never have bought.** A heading buys air above itself, which is right in the middle of a document and wrong at the top, where the pane's padding is already that air. It bit hardest where a repeated opener was skipped and left the next block sitting low. The first rendered block now carries no top air, whatever it is.

3. **A rail that only one tab has.** `ui-spec.md` routes to the Design tab and `mcp.md` to Architecture, so those two are the only tabs where more than one document lands and a rail of document capsules renders above the prose. A horizontal scroll view takes more height than the capsules inside it, seating that rail roughly 10pt below the first line of every tab without one — which is what the second measure caught, comparing Design against Mockups. The rail is now sized to its content.

That third one is worth remembering when reading a measure: **the tabs are not symmetrical.** Design and Architecture can carry a document rail; Mockups, Decisions, Issues and Timeline cannot. A gate that compares a rail tab against a rail-less one is comparing the right thing — they must still share an origin — but the cause will live in whichever part only one of them has.

It is also worth remembering how long that took. The origin was diagnosed three times from stills and fixed three times, and twice the fix moved nothing: the 28pt symbol was real and not the whole of it, and the chip rail's scroll-view slack was reasoned from code that the running app never rendered. **A measure that reports only a number invites another guess.** The script now names the view it scored — role and label, per tab — so the next disagreement is settled by the run rather than by argument.

> An empty tab may be empty. It may not shove the pane down. If a tab needs something above its first line, the something is wrong, not the origin.

## Locked — The selected sidebar row is always the unemphasized grey

One grey selected row, on every destination, focused or not. Portfolio, Timeline and the pinned projects all behave the same, and none of them ever goes accent blue.

The reason is legibility, not taste. An emphasized selection forces the row's content to white, and a project row is a coloured mark plus a name plus a key — the blue swallowed all three, so the row that told you where you were was the one row you could not read.

How it is achieved matters as much as the result. `NSColor.unemphasizedSelectedContentBackgroundColor` is a colour to draw with, not a mode to set: AppKit decides between the emphasized and unemphasized style from first-responder status, and `tint` only reaches the row's icons. We tried the tint first and it did nothing, which is exactly the trap. Finder, Mail and Music keep their sidebar lists from becoming first responder; Arkboard does the same, so the row keeps the system's own quiet rendering and its own colours.

> Do not paint a grey capsule behind the row to fake this. A hand-drawn selection drifts from the system's the first time Apple changes it, and it will not match the one in the Chat sheet three inches away.

## Locked — Frosted navigation, solid document

The reference is a dark glass IDE: frosted rails standing clearly in front of an opaque editor. What we take from it is the **relationship**, not the picture.

**Navigation is glass.** The sidebar, the window toolbar, the project tab rail and the Contents overlay take the system's material and nothing else — Liquid Glass on Tahoe behind an availability check, that release's material on macOS 14 and 15, and no third appearance we rolled ourselves. Nothing opaque is painted on any of them, which specifically means none of `documentField`, `card` or `editor` may appear in a navigation file, and no bar carries a second material inside a column that already has one.

**The document is solid.** The page, the Portfolio cards, the Gantt and every line of markdown sit on an opaque reading field. **Prose is never on glass.** Dark is a first-class look, not a tinted afterthought, and that is exactly where the rule earns itself: a frosted rail and a solid page can land close in value, so glass alone stops separating them.

**So the edges are drawn.** A 1pt hairline in `separatorColor` sits where a pane of glass meets what is under it — the bottom of the tab rail, the top of the sidebar footer, the leading edge of Contents. A line, never a filled strip: a strip is opaque paint on navigation wearing a disguise.

**What we are not taking.** No wallpaper or photograph behind the sidebar, and no `backdrop-filter` over a stock image — the material samples the desktop, which is the system's job and not ours to fake. No icon rail, no file tree, no editor tabs, no marketing chrome. The IA does not move: Portfolio, Timeline, a hairline, pinned projects; six project tabs; Contents as an overlay; Chat with Chief of Staff on a right-click. There is one sidebar.

> A still of another app is a description of a relationship, never a layout to copy. Take the relationship.

## Locked — The sidebar is material, the document is solid

The two columns are deliberately different surfaces. The sidebar is frosted system material with loosely paced rows; the document is an opaque reading field with the section wash over it. Side by side they read as slightly different colours, and that difference *is* the navigation-versus-content split, visible without reading a word.

`StudioColor.documentField` belongs to the document alone and `paneBackground` is its only caller. There is no window-background accessor for anything else, because painting one on a navigation surface is what blocked the glass in the first place.

## Locked — Onboarding, not Setup

The footer `sparkles` icon opens `product/onboarding.md`. It is a handbook, not Settings and not a gear labelled Setup.

## Locked — Design is the default tab

Opening a project lands on Design, not on Overview and not on Issues. A project is a design object first. The overview is always visible above the tabs anyway, so making it a tab would show it twice.

## Locked — Requirements become capabilities, and stay thin

The previous build had a `requirement` table that grew a markdown body, then a comment thread, then took over Monitor — a second document store by accident, which is exactly what this app must not have.

A capability is a title, a one-line note capped at 280 characters, and two independent signals: `state` for is-it-built, `health` for does-it-work. It exists to answer Monitor's second question and nothing else. When a capability needs explaining, the explanation goes in `product/`, and the capability points at that heading with `docPath` and `docAnchor`.

## Locked — GitHub issue sync is cut

Four MCP tools and three issue columns existed to mirror issues into GitHub. Nobody needs two trackers. GitHub now does exactly one job: serving a remote repository's `product/` folder when there is no local checkout.

## Locked — Port 7420, no fallback

Agents hard-code the address. If 7420 is taken, the server stays down and says so on Monitor and in Settings, with the reason. Silently moving to another port is worse than being offline, because everything keeps half-working.

## Locked — 13pt body, eight real faces, applied from the root

Default body is 13pt. Settings offers 12, 14, and 16, and eight faces that ship with macOS. Every piece of text derives from the body size through one type scale — no hard-coded `.title2` anywhere. Half the previous build's chrome ignored the setting, which made the setting feel broken even though it worked.

## Locked — Ten hues, one ramp

Sections claim a hue, states borrow three, agent avatars hash into the same set. Every colour in the app comes from one table with a light and a dark value. Colour appears as washes, chips, dots, and rules — never as body text.

## Locked — Seed one real project and nothing fictional

First run creates the workspace and the Arkboard project pointed at this repository. No demo project, no invented issues, no scripted three-bot conversation. The previous build seeded a fake dialogue and the first task on opening it was working out which rows were true.

## Locked — Clean slate, not a refactor

The rebuild deletes the old `Sources/`, `mcp/`, and project file and writes a new app against this pack. Old views are not wrapped, adapted, or kept "just for reference". The old tree is a graveyard; the git history is the reference.

## Locked — The design pack is the render test corpus

These six documents use every block the renderer must support: headings to four levels, prose, bullet and ordered lists, nested lists, tables, fenced code with a language, inline code, block quotes, horizontal rules, and relative links. If a document in this folder reads badly inside Arkboard, the renderer is wrong, not the document.

## Open — How should mockups be reviewed?

The Mockups tab currently specifies an image grid with a viewer sheet and any notes rendered underneath. Whether review actually wants a gallery, an ordered walkthrough with commentary between frames, or side-by-side comparison is unknown until there are real frames in the folder.

> Until it is answered: build the grid and the viewer as specified in [ui-spec.md](ui-spec.md). It is the cheapest thing that is useful, and it does not block a walkthrough later.

## Open — When does a capability leave Monitor?

Monitor shows capabilities whose health is `not_working`. Once an agent flips one to `working`, it vanishes. That is clean, but it means Monitor never shows you the things that were recently broken and are now fine, which is exactly what you want to know the morning after.

> Until it is answered: broken things only. If it turns out we want a memory, the field to use is `checkedAt` — recently healed capabilities sorted by it.

## Open — Should Arkboard watch `product/` for changes, or is Refresh enough?

Reloading on app activation plus a Refresh button covers the common case: edit in an editor, switch to Arkboard, see the change. A real file watcher would make it live, at the cost of an FSEvents stream per project and a class of bugs where the app reads a half-written file.

> Until it is answered: activation plus Refresh, both required. The watcher is optional and goes in last, if at all.

## Open — Who writes capabilities, and how do they stay in step with the documents?

Capabilities are written by agents through the API, and they point at headings in `product/`. Nothing keeps those pointers valid when a heading is renamed. It may not matter at this size, or it may rot within a month.

> Until it is answered: a capability whose `docPath` or `docAnchor` no longer resolves still renders, just without the jump. Never hide a capability because its link went stale.

## Locked — Issues is a project tab, not a sidebar row

The studio-wide Issues screen was leftover ticket chrome. Every project already has an Issues tab. That tab is where humans read tracking. The engine — SQLite, MCP `create_issue` / `update_issue` / comments — stays. There is no Issues row in the left sidebar.

## Open — What should a project with no repository on this machine do?

A project can have a `githubRepo` and no local checkout, in which case documents are fetched with the `gh` CLI — which may be missing, unauthenticated, or offline. The failure is a quiet line on the document tab (`Documents could not be read` plus the reason) and a `Try again` button. It is never a crash. Existing projects can set or edit both the local checkout and the GitHub remote from Settings or from the source caption in the project toolbar.

> Until it is answered: fail loudly and specifically. Never show the "a director pass will write this" empty state when the truth is that the documents could not be read. Those two states must never be confused.

## Open — Is the root `README.md` part of the rebuild?

The repository root README still describes the previous build as a "local Linear-style issue tracker" with statuses, priorities, and GitHub sync. It contradicts everything in this folder and it is the first thing anyone opening the repository reads.

> Until it is answered: the rebuild replaces it with a short README that describes the app in this pack and points here for detail. Nothing in the old one is worth keeping.
