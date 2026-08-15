# Decisions & questions

Locked calls and the questions still open. This file is the source of truth; notes in the app are extras.

## Locked — Product docs live in the repo

Design, architecture, mockups, and decisions are files under `product/`. The app surfaces them. It does not duplicate them in SQLite.

> If `product/` is missing, show a calm empty state. A director pass will write it. Do not prompt anyone to `create_requirement`.

## Locked — Human UI has no status pickers

Status, priority, and assignee stay in the engine for agents. The human chrome does not grow Linear-style pickers.

## Locked — One scroll per pane

Nested `List` inside `ScrollView` is out. Long documents get an outline that jumps in the same scroll.

## Open — How should mockups be reviewed?

Should a mockup page be a gallery of images, a written walkthrough, or both? Drop files in `product/mockups/` and we will learn by using it.

## Open — When does a requirement graduate off Monitor?

Monitor shows requirements that are not working. Once something is working, does it disappear, or stay as a quiet check?
