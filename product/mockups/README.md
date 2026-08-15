# Mockups

The Mockups tab is a gallery, not a markdown essay.

1. **Gallery** — every `png` / `jpg` / `webp` in this folder as a large thumb. Click to preview.
2. **Screen flow** — how those screens connect. Written in `flow.md` or `flow.json` (nodes + edges). If neither file exists, the tab infers a linear flow from the image filenames and says so.

Empty: `A director pass will drop screenshots here.`

## Adding a frame

1. Export a PNG, JPEG, or WebP into `product/mockups/`.
2. Name the file after the screen: `onboarding.png`, `home.png`, `detail.png`. The filename is the caption and the inferred flow order.
3. Optional: add `flow.md` (`onboarding → home → detail`) or `flow.json` with `nodes` and `edges`.

## What is worth mocking

- The project home at rest — overview band, pinned tabs, wash.
- A long document mid-scroll.
- Dark mode of either.
