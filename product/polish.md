# Polish

> **Historical record. Superseded, 2026-08-15.** This is the punch list from one audit of main @ `4cd6b9d`, kept because the reasoning is worth reading. Much of the chrome it argues about is gone: there is no overview band, no `New Project` in the sidebar footer, no in-page screen header, and the Timeline is a Gantt rather than a calendar. Read it as a record of how the app got here, not as a description of it. Current chrome is [design.md](design.md); current rules are [decisions.md](decisions.md).

A UI punch list from a live audit of main @ `4cd6b9d`, against seven screenshots of the running app. This is polish only: nothing here adds product. The portfolio stays on the left, Contents stays on the right, Monitor and Issues stay out of the left chrome, and `product/` stays the source of truth. Numbers and copy referenced here come from [design.md](design.md) and [ui-spec.md](ui-spec.md).

**Shipped** (this pass): C1, SB2, H1, T1, T2, O1, T3, D2, D3, plus cheap should-fix C2, O2, D4, E1. SB1: New Project is the sidebar footer, not a toolbar item. D1: the document measure is the pane width (overview, composer, tabs, markdown), left-aligned, pane padding only — not a 720 island when chrome is collapsed, not GridColumn 1000. Nits H2, H3, O3 left.

Screenshot key, used in every item below:

| # | Shows |
| --- | --- |
| S1 | Design tab, sidebar, Contents |
| S2 | Architecture tab |
| S3 | Mockups tab |
| S4 | Decisions & questions tab |
| S5 | Issues tab, empty |
| S6 | Timeline tab |
| S7 | Narrow window at 1080pt — tab bar overflowed |

## Must-fix, in order

1. **Contain the section wash to the pane.** It currently tints the window toolbar and bleeds under the left sidebar (worst on S3, where the lower two-thirds of the sidebar is magenta). — [item C1](#c1--the-wash-escapes-the-pane)
2. **Put the overview band back on plain window background.** The title, README lead, and composer pick up the section tint and change colour when you switch tabs (S1 vs S3). — [item H1](#h1--the-overview-band-is-tinted)
3. **Stop the sidebar toolbar icons overlapping.** New Project must not share a control group with the sidebar toggle or crowd the traffic lights — not in the title-bar pill when collapsed, not over the Origin Ark mark when open (S1–S6). — [item SB1](#sb1--toolbar-icons-overlap)
4. **Make all six tabs reachable at the minimum window.** At 1080pt wide, Timeline is cut off with no scroll affordance and no hint it exists (S7). — [item T1](#t1--the-tab-bar-silently-overflows)
5. **Give every tab the same left gutter and column cap.** One column family; tab rail left edge == document left edge. When the sidebar and/or Contents are gone, the page takes the room — no 720 island in a wide pane (S3, S5, S6 vs S1, S2). — [item D1](#d1--gutters-and-column-caps-differ-per-tab)
6. **Give Contents a close control.** The right column cannot be dismissed, ever, even at the minimum window where the document needs the room (all screenshots). — [item O1](#o1--contents-cannot-be-closed)
7. **Fix the clipped open-question chips on Decisions.** The third chip is cut mid-word at the right edge with no fade and no way to tell there are more (S4). — [item T3](#t3--the-open-question-chip-rail-clips)
8. **Render the Today rule exactly once on the Timeline.** It currently appears under *every* week that contains a future event — twice in S6, under "Week of 9 August" and again under "Week of 23 August". — [item D2](#d2--two-today-rules)
9. **Land the Timeline's initial scroll on Today.** The tab opens at the top of the spine instead of at the Today rule (S6); the scroll-to call is wired to a container that cannot scroll. — [item D3](#d3--timeline-does-not-open-at-today)

Everything below is the same list grouped by surface, with the smaller items included.

## Chrome — window and toolbar

### C1 — The wash escapes the pane

**Wrong.** The section wash is painted as a `.background` on the root of `ProjectHomeView`, so it extends past the pane into window chrome. Three symptoms: the toolbar strip is tinted on every tab (S1–S6); on S3 the magenta wash fills the lower two-thirds of the *left sidebar*; and the tint follows the selected tab into places the spec keeps neutral. [design.md](design.md) is explicit: the pane below the header carries the wash — nothing else does.

**Fix.** Paint the wash as an explicit layer inside the pane's own bounds — a `ZStack { wash; scroll }` clipped to the document column in `ProjectHomeView` — instead of `.background(...)` on the root view, which SwiftUI extends under the toolbar and window material. After the change: toolbar neutral, sidebar neutral, wash starts where the pane starts, on every tab.

**Severity: must.**

### C2 — The pinned tab bar is an opaque band

**Wrong.** The pinned tab bar paints opaque `windowBackgroundColor`. Once the overview scrolls away, a plain band sits on top of the washed document — a visible seam (edge of S1), which "no seams, no boxes inside boxes" forbids.

**Fix.** When pinned, back the tab bar with window background *plus* the current section wash (same two layers as the pane), so the strip is continuous with the document under it. A 1pt hairline at its bottom edge is fine; a colour step is not.

**Severity: should.**

## Sidebar

### SB1 — Toolbar icons overlap

**Wrong.** The New Project (`folder.badge.plus`) button and the system sidebar toggle share one leading title-bar pill and crowd the traffic lights. `.primaryAction` on `SidebarView` did not unstack them: when the sidebar is collapsed both icons sit next to the lights; when it is open they still live in the sidebar column header and overlap the Origin Ark mark.

**Fix.** New Project must not be a toolbar item and must not share a control group with the sidebar toggle. Put it in the sidebar footer (above the Agents strip). Verify sidebar-open (200–300pt) and sidebar-collapsed: the traffic-light cluster is only the system toggle; New Project is only in the footer, and is gone from the title bar when the sidebar is hidden.

**Severity: must.**

### SB2 — Wash shows through the sidebar

Same defect as C1, listed here so the sidebar check is not forgotten: after C1 lands, confirm on the Mockups tab (the strongest hue, S3) that the sidebar is back to plain sidebar material top to bottom.

**Severity: must** (fixed by C1; verify separately).

## Header — overview band

### H1 — The overview band is tinted

**Wrong.** [ui-spec.md](ui-spec.md): "The overview band sits on plain `windowBackgroundColor` so it reads as a header rather than as part of the section." On S1 the band is rose-tinted; on S3 it is magenta-tinted — it changes colour with the tab. The band does paint `windowBackgroundColor` today, but the escaped wash (C1) renders over/around it.

**Fix.** Falls out of C1: start the wash below the overview band (the band and the pinned tab bar are chrome; the wash belongs to the tab body). Verify by switching Design → Mockups: the title, README lead, and composer must not change colour.

**Severity: must.**

### H2 — Document chip casing is inconsistent

**Wrong.** On S1 the tab's document rail reads `design` and `ui spec` (lowercase) while the More documents chip reads `STATE` (uppercase). All three come straight from filename stems with no casing normalisation (`DocumentRouting.title(for:)`).

**Fix.** Normalise chip titles to sentence case: capitalise the first letter, lowercase the rest of an all-caps stem — `Design`, `Ui spec`, `State`. (Keep the existing `README` → `Overview` special case.)

**Severity: nit.**

### H3 — The Refresh button is a bare glyph

**Wrong.** The refresh arrow in the header trailing cluster (S1) is a plain-style button the size of the glyph — a small click target with no hover shape.

**Fix.** Use `.buttonStyle(.borderless)` or add ~4pt of padded `contentShape` so the target is comfortable; keep the `Refresh` help tooltip.

**Severity: nit.**

## Tabs

### T1 — The tab bar silently overflows

**Wrong.** At the 1080pt minimum window (S7), the pill row ends mid-`Issues` and Timeline is not visible at all. The row is a `ScrollView(.horizontal, showsIndicators: false)` — technically scrollable, but with no indicator, no edge fade, and no clipped-pill hint, it reads as "this app has five tabs". `⌘]` can select a tab you cannot see.

**Fix.** Three parts, all in `ProjectHomeView.tabBar`:

1. Add a trailing (and leading, when scrolled) edge fade — a ~24pt gradient mask — whenever the pill row's content width exceeds the viewport, so a cut pill is visibly a cut pill.
2. On tab selection (click or `⌘[`/`⌘]`), scroll the selected pill into view with `ScrollViewReader`.
3. Tighten the row until all six pills fit at the minimum window with the Contents column open: the document column has ~627pt there; drop the pill horizontal padding from 12 to 10 and the leading pane padding is already 24 — measure, and if six pills still do not fit, drop the symbol (keep the label) on unselected pills below a width threshold.

**Severity: must.**

### T2 — Tab order and reachability at narrow widths need a regression check

After T1, resize to exactly 1080 × 700 and confirm: all six pills visible or reachable with a visible affordance, Design → Timeline reachable by click alone, and the selected pill never hidden. This is the acceptance check for Riyu's S7 report.

**Severity: must** (verification of T1).

### T3 — The open-question chip rail clips

**Wrong.** On S4 the gold chip rail shows three chips, the third cut mid-word ("…or is Refresh enou") at the pane's right edge — same indicator-less horizontal scroll as T1, same problem: nothing signals more content, and the rail extends to the raw edge with no breathing room.

**Fix.** Either wrap the chips onto multiple lines (a flow layout; there are rarely more than a handful of open questions), or keep the single-line scroll and add the same edge fade as T1. Wrapping is the better reading experience and is one fewer horizontal scroller; prefer it. Keep each chip on one line with its full heading text.

**Severity: must.**

## Document

### D1 — Gutters and column caps differ per tab

**Wrong.** A centred 720 `ProseColumn` (and `MarkdownView`'s own 720 cap) leaves a skinny island when the sidebar and/or Contents are collapsed — huge gutters, tab rail full-bleed left, prose inset. Two left edges on one page. An earlier 1000 `GridColumn` for Mockups/Issues/Timeline was the same class of bug: two geometries in one tab family.

**Fix.** One column family on the project home. `ProseColumn` left-aligns and fills the pane (pane padding only). Do not use `GridColumn` (1000). Do not keep a 720 cap on `MarkdownView` here — Design through Timeline share the same measure. Tab rail left edge == document left edge, sidebar-open and sidebar-collapsed. When chrome is gone, the page takes the room. When both sidebars are open, filling the narrower pane is the measure; do not re-centre a 720 island.

**Severity: must.**

### D2 — Two Today rules

**Wrong.** S6 shows a moss `— Today —` rule under "WEEK OF 9 AUGUST" *and* under "WEEK OF 23 AUGUST". `TimelineSpine.shouldShowToday(before:in:)` evaluates per week, so every week containing a future event draws its own rule. There is one today; the spine must say so once.

**Fix.** Compute the single insertion index once over the whole ordered event list — before the first event whose date is in the future — and render exactly one rule there (after the last past event, before the first future one, even when that crosses a week header). If every event is in the past, the rule goes at the end; if every event is in the future, at the top. Also remove the duplicate `.id("today")` this currently creates.

**Severity: must.** Shipped, then superseded: the Timeline is now a Gantt, so Today is a single vertical rule on the time axis rather than a row inserted into a list. The invariant survived the rewrite — see **Locked — Timeline is a Gantt, not a calendar** in [decisions.md](decisions.md).

### D3 — Timeline does not open at Today

**Wrong.** [ui-spec.md](ui-spec.md): the Timeline's initial scroll is positioned at the Today rule. S6 opens at the top of the spine. In code, `TimelineSpine` wraps a plain `VStack` in a `ScrollViewReader` — but the actual scroll is the pane's outer `ScrollView` in `ProjectHomeView`, so `proxy.scrollTo("today")` is a no-op.

**Fix.** Drop the local `ScrollViewReader` from `TimelineSpine`. When the Timeline tab is selected, use the pane's existing `ScrollViewReader` in `ProjectHomeView` to scroll to the (now unique, per D2) `today` anchor, instantly on first appearance, respecting Reduce Motion.

**Severity: must.** Shipped, then superseded: the Gantt has no vertical spine to scroll, and its axis window always contains Today, so there is nothing to scroll to.

### D4 — Done-issue rows repeat their identifier

**Wrong.** `TimelineBuilder` composes a done issue's row title as `"IDENT  Title"` and *also* attaches the identifier as a chip, so the same `ARK-n` prints twice per row. (S6's chips under the smoke entries are milestone `relatedIdentifiers`, which are correct — this item is about the issue rows the builder emits.)

**Fix.** Per [ui-spec.md](ui-spec.md), a completed-issue row is: small moss dot, identifier, title — no chips, no description line. Drop `identifiers` from the issue events in `TimelineBuilder` and render the identifier once, in `mono` `caption`, before the title.

**Severity: should.** Shipped, then superseded: a completed issue is no longer a row. On the Gantt it is a moss tick on its project's bar, naming the identifier and title once, on hover.

## Contents

### O1 — Contents cannot be closed

**Wrong.** The right column is a fixed `.frame(width: 220)` in `RootView` with no control to dismiss it (all screenshots; Riyu named it). At the minimum window it permanently takes 220pt the document could use.

**Fix.** Add a toolbar toggle at the trailing edge of the window toolbar — `sidebar.trailing` symbol, `⌥⌘0`-style behaviour is not required, a click is enough — that collapses and restores the Contents pane with a short animation (instant under Reduce Motion). Persist the state (e.g. `arkboard.contentsVisible`) across launches and projects. Contents stays on the right; this is a close control, not a relayout.

**Severity: must.**

### O2 — Contents width is fixed, not a range

**Wrong.** The spec gives Contents 220 ideal / 180 min / 280 max, but the pane is hard-coded to 220 and cannot be resized (all screenshots).

**Fix.** Make the trailing pane user-resizable within 180–280 (a drag handle on the divider between document and Contents), defaulting to 220. Combined with O1, the document column always has a way to get its room back.

**Severity: should.**

### O3 — Contents top does not align with the pane

**Wrong.** The `Contents` caption floats with its own ad-hoc 16pt top padding (S1) and does not sit on the pane's 20pt vertical rhythm, so it lands at a different height than the document header beside it.

**Fix.** Give the Contents column the standard pane padding (24 horizontal is too wide for a 220pt column — keep 12 horizontal, but use `paneY` = 20 top) so the `Contents` caption baseline-aligns with the top of the document column's content.

**Severity: nit.**

## Empty states

### E1 — Empty states sit high in the pane

**Wrong.** On S5 the `No issues` block renders at the top of the washed area, directly under the `Tracking only…` line, leaving a large dead field below it. The spec's shape ("centred, with 40pt of air") reads as centred in the visible pane, not stacked at the top.

**Fix.** Give `EmptyStateView` a generous `minHeight` so the empty block has room in the washed pane. On the project home the block is leading — same left edge as the Design heading — not a centred poster. Vertical air stays; horizontal centering does not.

**Severity: should.**

### E2 — Empty-state copy check

The copy visible in S5 (`No issues` / `Nothing has been filed here.`) and the no-outline line in S5/S6 (`This page has no subsections.`) match [ui-spec.md](ui-spec.md) exactly. No change; noting it so nobody "fixes" it.

**Severity: none — leave as is.**

## Acceptance for this list

Done means, on one relaunch:

1. Switch Design → Mockups → Timeline: toolbar, sidebar, and overview band never change colour; only the tab body's wash does (C1, H1, SB2).
2. Every tab shares one left edge with the tab rail. When the sidebar and/or Contents are collapsed, the document fills the pane (no 720 island). No 1000pt family (D1).
3. At 1080 × 700 all six tabs are visible or visibly scrollable, and selecting Timeline via `⌘]` scrolls its pill into view (T1, T2).
4. The Timeline shows exactly one Today rule and opens scrolled to it (D2, D3).
5. Decisions shows every open-question chip in full, wrapped or fading, never cut mid-word (T3).
6. Contents can be closed from the toolbar and reopened, and the choice survives relaunch (O1).
7. New Project is in the sidebar footer, never in the traffic-light pill, at 200–300pt sidebar width and when the sidebar is collapsed (SB1).
