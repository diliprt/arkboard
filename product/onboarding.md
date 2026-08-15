# Onboarding

How Origin Ark Studio works. If you are a new agent subscription — Grok, Cursor, or otherwise — read this file first. Point at it. Do not invent a second handbook.

## What this studio is

**Origin Ark Studio** ([originarkstudio.com](https://originarkstudio.com)) is one human and a small set of agents.

The human is **Riyu**. There is no other operator.

**Arkboard** is the local studio board: a SwiftUI macOS app, a SQLite database, and an MCP / REST listener on localhost port **7420**. Humans read. Agents execute. Documents live in Git under `product/`. What happened — issues, notes, milestones, capability health — lives in SQLite.

This repository is the app. This folder is the director pack.

## How the team is split

Do not invent extra bots. These are the seats:

| Seat | Job | Notes |
| --- | --- | --- |
| **Chief of Staff** | Roadmap, specs, shipping, merges | Arkboard MCP actor remains `Product` |
| **Design** | Visual and IA | Only when asked. Do not bounce frames into Riyu's chat unasked |
| **Product Critique** | PASS / NOT YET | After UI ships, not before |
| **Apple Build** | Xcode on the Mac | Existing checkout only. Delete leftover worktrees |
| **Android Build** | Kotlin / Compose | Apple-first, Android-follow |
| **Ops** | Runtime and health | |
| **Comms** | Words that leave the studio | No public posts without Riyu |
| **Company Tracker** | Site and news | |

Riyu is reserved for the human sitting at the app. Do not send `actor=Riyu` from an agent.

## Where work lives

- **GitHub `diliprt/arkboard`** is the app.
- Per-app **`product/`** is the director pack: design, architecture, mockups, decisions, and this onboarding page.
- When you add a project, drop a card image at **`product/card.png`**. That picture is its Portfolio card face. Without one the card falls back to the project's mark, and then to a plain field in its colour.
- **Cursor cloud agents** write repo code against the saved environment `diliprt/arkboard`.
- **Never clone** onto the Linux box or the Mac for source work. The checkout already exists.
- The **Mac** is for `xcodebuild`, Arkboard.app, and localhost MCP. Cloud agents are Linux only — no `xcodebuild` there.

## GitHub connections

A project may have a local checkout path (`repoPath`), a GitHub remote (`githubRepo` as `owner/name`), or both.

Documents load from local `product/` first. If there is no local folder, they load from GitHub through `gh`. The New Project sheet sets both fields. Whichever sources exist show on the project page, in the Refresh action's help text — not on the Portfolio card, which is a picture.

## How to run Arkboard

From the existing checkout:

```bash
./scripts/run.sh
```

Or run the Debug `.app` from `/Users/dilipreddy/Origin Ark Studio/arkboard`.

MCP and REST:

```
http://127.0.0.1:7420
```

Mutations pass `actor=Product` (Chief of Staff). Other seats use their own name. See [mcp.md](mcp.md).

```bash
python3 scripts/spec_check.py
```

That is the Linux-runnable contract check. It does not launch the app.

## Standing orders

1. **Chief of Staff merges PRs.** Do not ask Riyu to rubber-stamp.
2. **Latest brief wins.** If a later note contradicts an earlier one, the later note is the contract.
3. **No status, priority, or assignee** in the human UI. Those fields exist for agents. Humans see Underway / Queued / Done grouping only.
4. **No issue creation** in the human UI. Say it in the compact note sheet. An agent files it.
5. **Product Critique** is PASS or NOT YET after UI ships.
6. **Mac-first measures before Critique.** A UI change is measured before it is reviewed: Apple Build compiles it on the existing Mac checkout — no worktrees — and runs `./scripts/mac_measure.sh` against the running Debug build, then pastes that JSON into the Critique packet. A still without the click measures is not a review, because a screenshot cannot show a body that moves 52pt under a rail that never does. The script exits non-zero when the numbers drift; that is a failed build, not a conversation. See `product/decisions.md`, "Locked — Mac-first measures before Critique".
7. **Do not bounce Design frames** into Riyu's chat unless asked.

## Current chrome

Left sidebar, top to bottom:

1. **Portfolio** — destination. Cards of every app: brand, name, key, one-line description (README lead or stored summary), `local · …` and/or `github · owner/name`, four doc pills (Design, Architecture, Mockups, Decisions), and a pin. Clicking a card opens the project. Pinning puts the project on the sidebar; unpinning removes it from the sidebar and leaves it on Portfolio.
2. **Timeline** — destination. The studio rollup as a Gantt: every project a row, its milestones underneath, bars on one time axis, and links showing which milestone waits on which. Scale is `Week` / `Month` / `Quarter`, default Month. Clicking a project row opens that project's Timeline tab, the same chart scoped to it. Read-only — agents set milestones and their `dependsOn` predecessors through the API.
3. **Pinned projects** — brand, name, key. Clicking opens the project home on Design.

Footer: an **Onboarding** `sparkles` icon (this page) and **Agents · :7420**. **New Project** lives on the Portfolio page only.

Project pages: thin header (mark, name, key, source, refresh, note icon) and six tabs. No overview article. No large composer. Feedback is the compact icon with history from Activity.

Onboarding is this page. It is not Settings and it is not labelled Setup.
