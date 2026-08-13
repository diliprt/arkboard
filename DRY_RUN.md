# Arkboard multi-bot dry-run

Updated: 2026-08-12 (PT)

## Goal
All bots can access Arkboard via MCP to add comments/updates, raise requests, features, bugs. Linear-like flow with GitHub link/sync against private test repo. Retest until smooth.

## Assets
- Private repo: https://github.com/diliprt/arkboard-dry-run (private)
- Arkboard project: DRY / Dry Run Mini (`githubRepo=diliprt/arkboard-dry-run`)
- GH mirrors linked: issues/1 ↔ DRY-1, issues/2 ↔ DRY-2

## Bot access (PASS)
- [x] create_project (Product → DRY)
- [x] create_issue feature + bug labels (Product → DRY-1, DRY-2)
- [x] create_issue chore (Ops DRY-3, Comms DRY-4)
- [x] add_comment with actor attribution + @mentions
- [x] update_issue status (Ops → in_progress, Comms → done)
- [x] Activity actors Product/Ops/Comms

## Gaps (remaining)
1. ~~BLOCKER No GitHub fields~~ **FIXED** (v6 migration + models)
2. ~~BLOCKER No MCP tools~~ **FIXED** (`set_project_github_repo`, `link_github_issue`, `create_github_issue`, `unlink_github_issue`)
3. ~~MAJOR No UI affordance~~ **FIXED** (Issue detail GitHub section)
4. ~~MAJOR Manual GH issues separately~~ **FIXED** (link existing + create via `gh`)
5. **MINOR** No automated comment mirror Arkboard↔GitHub (nice-to-have v1)
6. ~~MINOR Project-level default repo~~ **FIXED**

## Success checklist
- [x] Project DRY has githubRepo = diliprt/arkboard-dry-run
- [x] DRY-1 linked to GH #1; DRY-2 to GH #2
- [x] MCP create_github_issue creates GH issue + stores link (DRY-5 → GH #5; also DRY-6/#4, DRY-7/#3)
- [x] MCP link_github_issue attaches existing number/URL
- [x] Issue detail shows GitHub link
- [x] smoke.sh green (40/40)
- [ ] Multi-bot retest: create → link/create GH → comment → status update still works
- [ ] Delete routine arkboard-dry-run-loop when all pass

## Status
SHIPPED MVP — GitHub link/sync working; remaining: multi-bot retest + cleanup routine
