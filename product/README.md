# Arkboard

Arkboard is Origin Ark Studio's local studio board for macOS. It is a reading room first and a tracker second: humans open a project and read what it is supposed to be, agents do the work and report back through a localhost API. Everything lives on this machine — a SQLite file and the `product/` folder in each repo.

## The thesis

Three sentences, and every other decision in this folder follows from them.

1. **Local-first.** No account, no cloud, no sync service. A SQLite database in Application Support and markdown in Git.
2. **Humans read and steer.** Riyu opens a project to understand it, not to groom a backlog. The human surface is for reading and saying things out loud.
3. **Agents execute.** Cursor, Grok, and anything else that speaks MCP file issues, mark what works, close milestones, and talk in Activity — through `127.0.0.1:7420`, with a name attached to every write.

## What you see when you open it

The left sidebar is the studio home: a portfolio of every project, each with that app's own mark. Click a project and you get a document home, not a ticket list. A short overview at the top, then tabs:

| Tab | What it is | Where it comes from |
| --- | --- | --- |
| Design | How it should look and feel | `product/design.md` |
| Architecture | How it is built | `product/architecture.md` |
| Mockups | Screenshot gallery and screen flow | `product/mockups/` |
| Decisions & questions | Locked calls, open threads | `product/decisions.md` |
| Issues | Tracking, read-only for humans | SQLite |
| Timeline | Milestones and what shipped | SQLite |

The first four tabs render markdown from that repo's `product/` folder as a **rich preview** — real headings, lists, code blocks, quotes, tables, links, images. Never a wall of raw `.md`. Long documents list their headings in the right-hand **Contents** column; click one to jump to that subsection.

## Where the truth lives

`product/` in Git is the source of truth for what a project is. Arkboard reads it. Arkboard never writes it and never copies it into the database.

> If a project has no `product/` folder, you get a calm empty state — "a director pass will write this" — not a prompt, not a wizard, and not the name of an MCP tool. Documents are written by a director pass in the repo, in an editor, and committed.

The database holds only what documents cannot: issues, comments, activity, milestones, and capability health. That split is the whole architecture.

## What is deliberately missing

Riyu does not assign work, so the human UI has **no status field, no priority field, and no assignee picker** anywhere. Agents set those through the API; humans never see a dropdown for them. There is no issue-creation form either. If something needs to happen, you say it on the project and an agent files it. Monitor and Issues are not left-sidebar rows; Issues stays as a tab on the project page.

## What's in this folder

This is the design pack. It is the specification the app is built from, and it is also the app's own `product/` folder — so Arkboard renders these six files as its own project home. If a document reads badly in the app, the renderer is wrong.

- **README.md** — you are here. Overview and the shape of the thing.
- **[design.md](design.md)** — the visual system. Color, type, spacing, scroll, markdown rendering.
- **[architecture.md](architecture.md)** — data model, SQLite schema, the localhost server, how `product/` is surfaced.
- **[ui-spec.md](ui-spec.md)** — every screen and tab, every empty state, every exclusion.
- **[mcp.md](mcp.md)** — the agent API. Tool list, contracts, examples.
- **[decisions.md](decisions.md)** — what is locked, what is still open.
- **[mockups/](mockups/)** — frames, when there are frames.

## Running it

```bash
./scripts/run.sh          # build Debug and launch Arkboard.app
curl -s 127.0.0.1:7420/health | jq
./scripts/smoke.sh        # proves the database and the agent API are alive
```

macOS 14 or later. Xcode 15+. XcodeGen for the project file. Details in [architecture.md](architecture.md).
