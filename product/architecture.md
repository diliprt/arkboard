# Architecture

Arkboard is a local macOS app: SwiftUI chrome, GRDB/SQLite engine, and a localhost MCP server on port 7420.

## Shape

```
ArkboardApp
  AppStore          single write path + activity
  GRDB DatabasePool Application Support
  MCPServer         127.0.0.1:7420
  ProductLibrary    in-memory cache of repo product/
  Views             studio shell + project documents
```

## Persistence

Local SQLite with GRDB migrations v1–v7. Projects, issues, requirements, comments, activity, milestones, GitHub links, soft-delete. The engine is sacred; the chrome is not.

## MCP

Agents list, create, and update issues and requirements through localhost. Actor attribution lands in Activity. Humans do not get status or priority pickers.

## Product docs

Prose lives in the git repo under `product/`. If the project has a GitHub repo (`owner/name`), the app fetches that tree. Arkboard also reads its own local `product/` when present. Nothing here is copied into SQLite.

## What we do not store

We do not invent a second CMS for design or architecture. A short in-app note on Decisions can land as an activity row. That is a sticky, not a document store.
