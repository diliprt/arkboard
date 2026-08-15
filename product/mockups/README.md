# Mockups

The Mockups tab is a gallery, not a markdown essay.

1. **Gallery** — every `png` / `jpg` / `webp` in this folder as a large thumb. Click to preview.
2. **Screen flow** — how those screens connect. Written in `flow.md` or `flow.json` (nodes + edges). If neither file exists, the tab infers a linear flow from the image filenames and says so.

Empty: `A director pass will drop screenshots here.`

## Adding a frame

1. Export a PNG, JPEG, or WebP into `product/mockups/`.
2. Name the file after the screen: `onboarding.png`, `home.png`, `detail.png`. The filename is the caption and the inferred flow order.
3. Optional: add `flow.md` (`onboarding → home → detail`) or `flow.json` with `nodes` and `edges`.

Brand artwork at the root of `product/` — `card.png`, `icon.png`, `mark.png`, `logo.png` — is the project's own face and is routed out of this gallery. A poster is not a frame someone drew.

## These are the current build

Mockups are the **latest measured window shots**, taken from the build on `main` and replaced in the same pull request as the chrome they show. `product/` is what Arkboard renders, so a gallery of last month's chrome is a stale screen inside the running app. An empty folder is honest; an out-of-date one is not.

Shots come from the run that produced the Mac measures, so the frame and the numbers describe the same build. See `product/decisions.md`, "Locked — product/ tabs are living" and "Locked — Mac-first measures before Critique".

## What is worth shooting

- Portfolio at rest — the poster cards, the quiet sidebar, the one title row.
- A project page on Design — pinned tab rail, mark and key in the toolbar, no second headline.
- The same page with Contents open, showing the reserved gutter.
- Timeline — the Gantt with a dependency link and the Today rule.
- Dark mode of any of them.
