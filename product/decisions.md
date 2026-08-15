# Decisions & questions

What is settled, and what is still open. This file is the source of truth for both. A note typed into the app is a sticky; this is the record.

The headings here are load-bearing. Arkboard parses this document to build Monitor's open-questions lane, and the rule is simple: a heading starting with **Locked** or **Decided** is settled, and a heading starting with **Open** or ending in a question mark is not. Keep the convention when you add to this file, and Monitor stays honest for free.

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

Portfolio is a destination. Timeline is a destination. A hairline separates those two rows from pinned projects below. The workspace name lives in the window subtitle — no Origin Ark icon or row in the sidebar. Create lives on the Portfolio page, not in the left chrome. Monitor, Issues, and Activity are not sidebar rows. Existing projects start pinned. Unpinning removes a row from the sidebar and leaves the project on the Portfolio page.

## Locked — Timeline is a calendar

The reading view is Week / Month / Year, default Month. The master Timeline is the studio rollup. The project Timeline tab is the same calendar, scoped. The old vertical Today-spine is not the primary UI. Milestones stay in SQLite; there is no second timeline store. Humans do not edit milestones.

## Locked — The project home is a thin header

No README article and no large composer sit above the tabs. The long description lives on the Portfolio card. Feedback is a compact icon that opens a note plus Activity history. `⌘N` focuses that sheet.

## Locked — Chat with Chief of Staff is the board inbox

Right-click anywhere — sidebar, document, tabs, calendar, cards, onboarding, empty states — offers `Chat with Chief of Staff`. That item opens the compact note sheet with the current highlight prefilled and a quiet friendly page line. Sending writes a `handoff` Activity to `Product` through `post_note`. The Activity body is the typed note plus that friendly line — not a destination/project/ISO dump. The board is the inbox. Do not open an external chat.

## Locked — Apple language, not Apple content

Arkboard borrows how Apple's design team builds a Mac app. It borrows nothing else. No Apple Music screens, no playlists, no album art, no lifted copy, no branding. What we take is the grammar: system materials, system controls, one type scale, concentric corners, content edge to edge with navigation floating above it.

The dividing line is Liquid Glass, and it is the whole rule. Glass is the **navigation** layer — sidebar, window toolbar, project tab rail, Contents inspector. The document is the **content** layer and stays solid, because prose on glass cannot be read. If a surface is asking "where am I / show me something else", it is glass; if it is the thing you came to read, it is not.

The practical consequence is subtraction, not addition. Custom backgrounds behind navigation surfaces sit on top of the system material and block it, so the fix for a sidebar that will not look like a sidebar is to delete the paint, not to mix a better colour. Filters are native accessory-bar capsules with the section hue as their tint, not hand-drawn pills; the shape, hover, and selected state come from the system and therefore match Finder and Mail for free.

> Deployment stays at macOS 14. Every Tahoe API sits behind an availability check with a system-material fallback, so the app has two appearances — this release's materials and Liquid Glass — and never a third one of our own invention.

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

A project can have a `githubRepo` and no local checkout, in which case documents are fetched with the `gh` CLI — which may be missing, unauthenticated, or offline. The failure is currently a message in the project header and a line in Monitor's health strip.

> Until it is answered: fail loudly and specifically. Never show the "a director pass will write this" empty state when the truth is that the documents could not be read. Those two states must never be confused.

## Open — Is the root `README.md` part of the rebuild?

The repository root README still describes the previous build as a "local Linear-style issue tracker" with statuses, priorities, and GitHub sync. It contradicts everything in this folder and it is the first thing anyone opening the repository reads.

> Until it is answered: the rebuild replaces it with a short README that describes the app in this pack and points here for detail. Nothing in the old one is worth keeping.
