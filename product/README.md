# Arkboard

Arkboard is Origin Ark Studio’s local home for a product — a colorful, document-first macOS app with a real tracker underneath. Humans read design and architecture. Agents file issues and talk in Activity.

## What it is

A SwiftUI shell over local SQLite. The human page for a project is a short overview plus the files in that repo’s `product/` folder. Issues and milestones stay in the engine; they are not the front door.

## Who it's for

Riyu steers. Agents execute. The chrome should feel like a studio notebook, not a grey ticket cockpit.

## How the studio uses it

1. Open a project to read Design, Architecture, Mockups, and Decisions.
2. Use **Monitor** for a bird’s-eye of open questions and requirements that are not working.
3. Use **Issues** when you need the tracking list. Agents still create and update tickets through the local API.

## What's in this folder

This `product/` tree is the source of truth the project page surfaces. A director pass writes it. The app does not invent a second document store.
