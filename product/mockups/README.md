# Mockups

Frames live in this folder. The Mockups tab on the project home renders every image here as a grid, with any notes like this one underneath.

There are no frames yet. Arkboard is being built directly from [design.md](../design.md) and [ui-spec.md](../ui-spec.md), which carry the numbers a mockup would otherwise carry — the ramp, the type scale, the metrics, and the copy for every empty state.

## Adding a frame

1. Export a PNG or JPEG into `product/mockups/`.
2. Name the file after the screen it shows: `monitor.png`, `project-home-design-tab.png`, `issues-three-column.png`. The filename is the caption.
3. Add a line here saying what the frame is arguing for, if it is not obvious.

## What is worth mocking

Most of this app is specified precisely enough to build without a frame. The places where a picture would actually settle something:

- **The project home at rest** — how much air the overview band takes before the tab bar pins, and whether the wash reads as identity or as noise.
- **A long document mid-scroll** — the pinned tab bar and outline together, with prose underneath, to check the header stack is not too heavy.
- **Monitor with real content** — three open questions and two broken capabilities, to see whether gold and crimson sitting near each other is calm or alarming.
- **Dark mode of any of the above.**

## Review

Walk the frames top to bottom. If a frame settles something, write the call into [decisions.md](../decisions.md) as a `Locked —` heading. If it raises something, write it as an `Open —` heading and it will show up on Monitor.
