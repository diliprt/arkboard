#!/usr/bin/env bash
# Smoke-test Arkboard MCP/REST while the macOS app is running.
# Fully runnable on a Mac with Arkboard.app listening on 127.0.0.1:7420.
set -euo pipefail

BASE="${ARKBOARD_BASE:-http://127.0.0.1:7420}"
PASS=0
FAIL=0

green() { printf '\033[32m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }
info() { printf '→ %s\n' "$*"; }

check_json() {
  local name="$1"
  local body="$2"
  local jq_expr="$3"
  if echo "$body" | jq -e "$jq_expr" >/dev/null 2>&1; then
    green "PASS  $name"
    PASS=$((PASS + 1))
  else
    red "FAIL  $name"
    echo "$body" | head -c 800
    echo
    FAIL=$((FAIL + 1))
  fi
}

TOOLS_REQUIRED=(
  list_projects create_project update_project list_documents read_document
  list_issues get_issue create_issue update_issue delete_issue restore_issue
  add_comment post_note list_activity
  list_milestones create_milestone update_milestone
  list_capabilities create_capability update_capability
)

info "Health $BASE/health"
HEALTH="$(curl -sfS --max-time 3 "$BASE/health" || true)"
if [[ -z "$HEALTH" ]]; then
  red "FAIL  health (is Arkboard.app running? launch via ./scripts/run.sh on a Mac)"
  exit 1
fi
check_json "health name" "$HEALTH" '.name == "Arkboard"'
check_json "health database" "$HEALTH" '.database == "ok"'
check_json "health version" "$HEALTH" '.version == "2.0.0"'

info "MCP tools/list"
TOOLS="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')"
check_json "tools/list array" "$TOOLS" '.result.tools | type == "array"'
for tool in "${TOOLS_REQUIRED[@]}"; do
  check_json "tools include $tool" "$TOOLS" "[.result.tools[].name] | index(\"$tool\") != null"
done
check_json "no GitHub sync tools" "$TOOLS" '[.result.tools[].name] | index("link_github_issue") == null'
check_json "no create_requirement" "$TOOLS" '[.result.tools[].name] | index("create_requirement") == null'

TITLE="Smoke $(date +%Y%m%d-%H%M%S)"
info "MCP create_issue with actor Ops ($TITLE)"
CREATE="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg t "$TITLE" '{
    jsonrpc:"2.0", id:2, method:"tools/call",
    params:{ name:"create_issue", arguments:{ projectKey:"ARK", title:$t, status:"todo", labels:["smoke"], actor:"Ops" } }
  }')")"
check_json "create_issue title" "$CREATE" '.result.structuredContent.title == "'"$TITLE"'" or (.result.content[0].text | contains("'"$TITLE"'"))'
IDENT="$(echo "$CREATE" | jq -r '.result.structuredContent.identifier // empty')"
ISSUE_ID="$(echo "$CREATE" | jq -r '.result.structuredContent.id // empty')"
info "Created identifier: ${IDENT:-unknown}"

info "MCP list_activity names Ops"
ACT="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_activity","arguments":{"limit":20,"projectKey":"ARK"}}}')"
check_json "list_activity has Ops" "$ACT" '(.result.structuredContent.activities // []) | map(.actor) | index("Ops") != null or (.result.content[0].text | contains("Ops"))'

if [[ -n "$IDENT" || -n "$ISSUE_ID" ]]; then
  info "MCP update_issue done sets completedAt"
  KEY="${ISSUE_ID:-$IDENT}"
  DONE="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$KEY" '{
      jsonrpc:"2.0", id:4, method:"tools/call",
      params:{ name:"update_issue", arguments:{ id:$id, identifier:$id, status:"done", actor:"Product" } }
    }')")"
  check_json "done sets completedAt" "$DONE" '.result.structuredContent.completedAt != null'
  REOPEN="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$KEY" '{
      jsonrpc:"2.0", id:5, method:"tools/call",
      params:{ name:"update_issue", arguments:{ id:$id, identifier:$id, status:"todo", actor:"Product" } }
    }')")"
  check_json "leaving done clears completedAt" "$REOPEN" '.result.structuredContent.completedAt == null'
fi

if [[ -n "$IDENT" || -n "$ISSUE_ID" ]]; then
  KEY="${ISSUE_ID:-$IDENT}"
  info "MCP add_comment multi-mention"
  MM="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$KEY" '{
      jsonrpc:"2.0", id:6, method:"tools/call",
      params:{ name:"add_comment", arguments:{ issueId:$id, identifier:$id, body:"@Ops @Comms please both review multi-mention smoke", actor:"Product" } }
    }')")"
  check_json "add_comment multi-mention" "$MM" '(.error | not) and ((.result.structuredContent.body // .result.content[0].text) | test("@Ops") and test("@Comms"))'
  MM_ACT="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"list_activity","arguments":{"limit":40,"projectKey":"ARK"}}}')"
  if [[ -n "$IDENT" ]]; then
    check_json "multi-mention is one activity row" "$MM_ACT" "([(.result.structuredContent.activities // [])[] | select((.body|test(\"multi-mention\")) and (.issueIdentifier == \"$IDENT\"))] | length) == 1"
    check_json "multi-mention targetActors" "$MM_ACT" "([(.result.structuredContent.activities // [])[] | select((.body|test(\"multi-mention\")) and (.issueIdentifier == \"$IDENT\"))][0].targetActors | unique | sort == [\"Comms\",\"Ops\"])"
  fi
fi

if [[ -n "$IDENT" || -n "$ISSUE_ID" ]]; then
  KEY="${ISSUE_ID:-$IDENT}"
  info "MCP delete_issue / restore_issue"
  DEL="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$KEY" '{
      jsonrpc:"2.0", id:8, method:"tools/call",
      params:{ name:"delete_issue", arguments:{ id:$id, identifier:$id, actor:"Ops" } }
    }')")"
  check_json "delete_issue sets archivedAt" "$DEL" '.result.structuredContent.archivedAt != null'
  HIDDEN="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"list_issues","arguments":{"projectKey":"ARK","query":"Smoke"}}}')"
  if [[ -n "$IDENT" ]]; then
    check_json "list_issues hides archived" "$HIDDEN" "([(.result.structuredContent.issues // [])[] | select(.identifier == \"$IDENT\")] | length) == 0"
  fi
  SHOWN="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"list_issues","arguments":{"projectKey":"ARK","includeArchived":true,"query":"Smoke"}}}')"
  if [[ -n "$IDENT" ]]; then
    check_json "includeArchived returns issue" "$SHOWN" "([(.result.structuredContent.issues // [])[] | select(.identifier == \"$IDENT\")] | length) == 1"
  fi
  RES="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$KEY" '{
      jsonrpc:"2.0", id:11, method:"tools/call",
      params:{ name:"restore_issue", arguments:{ id:$id, identifier:$id, actor:"Product" } }
    }')")"
  check_json "restore_issue clears archivedAt" "$RES" '.result.structuredContent.archivedAt == null'
fi

info "MCP create_milestone unknown related issue"
BAD_REL="$(curl -sS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc":"2.0","id":12,"method":"tools/call",
    "params":{"name":"create_milestone","arguments":{"title":"Bad related smoke","targetDate":"2030-01-01","relatedIssueIdentifiers":["ARK-99999"],"actor":"Ops"}}
  }')"
check_json "unknown related issue error" "$BAD_REL" '.error.message | test("Unknown related issue")'

if [[ -n "$IDENT" ]]; then
  GOOD_REL="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "Related smoke $(date +%Y%m%d-%H%M%S)" --arg ident "$IDENT" '{
      jsonrpc:"2.0", id:13, method:"tools/call",
      params:{ name:"create_milestone", arguments:{ title:$t, projectKey:"ARK", targetDate:(now | strftime("%Y-%m-%d")), relatedIssueIdentifiers:[$ident], actor:"Product" } }
    }')")"
  check_json "create_milestone with related issue" "$GOOD_REL" '(.error | not) and ((.result.structuredContent.relatedIssueIdentifiers // []) | index("'"$IDENT"'") != null)'
fi

REQ_TITLE="Smoke capability $(date +%Y%m%d-%H%M%S)"
info "MCP create_capability / update_capability not_working"
REQC="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg t "$REQ_TITLE" '{
    jsonrpc:"2.0", id:14, method:"tools/call",
    params:{ name:"create_capability", arguments:{ projectKey:"ARK", title:$t, note:"smoke check", actor:"Product" } }
  }')")"
check_json "create_capability" "$REQC" '.result.structuredContent.title == "'"$REQ_TITLE"'"'
CAP_ID="$(echo "$REQC" | jq -r '.result.structuredContent.id // empty')"
CAP_IDENT="$(echo "$REQC" | jq -r '.result.structuredContent.identifier // empty')"
if [[ -n "$CAP_ID" || -n "$CAP_IDENT" ]]; then
  KEY="${CAP_ID:-$CAP_IDENT}"
  REQU="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$KEY" '{
      jsonrpc:"2.0", id:15, method:"tools/call",
      params:{ name:"update_capability", arguments:{ id:$id, identifier:$id, health:"not_working", actor:"Ops" } }
    }')")"
  check_json "update_capability not_working" "$REQU" '.result.structuredContent.health == "not_working"'
  LISTC="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"list_capabilities","arguments":{"projectKey":"ARK","health":"not_working"}}}')"
  check_json "list_capabilities health filter" "$LISTC" '.result.structuredContent.capabilities | type == "array" and length >= 1'
fi

info "Validation errors"
EMPTY="$(curl -sS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg id "${ISSUE_ID:-}" --arg ident "${IDENT:-ARK-1}" '{
    jsonrpc:"2.0", id:17, method:"tools/call",
    params:{ name:"add_comment", arguments:(if $id != "" then {issueId:$id, body:"   ", actor:"Ops"} else {identifier:$ident, body:"   ", actor:"Ops"} end) }
  }')")"
check_json "empty comment error" "$EMPTY" '.error.message | test("Comment cannot be empty")'

BAD_STATUS="$(curl -sS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg id "${ISSUE_ID:-}" --arg ident "${IDENT:-ARK-1}" '{
    jsonrpc:"2.0", id:18, method:"tools/call",
    params:{ name:"update_issue", arguments:(if $id != "" then {id:$id, status:"nope", title:"should-not-apply", actor:"Ops"} else {identifier:$ident, status:"nope", title:"should-not-apply", actor:"Ops"} end) }
  }')")"
check_json "invalid status error" "$BAD_STATUS" '.error.message | test("Unknown status|Invalid status")'

BAD_DATE="$(curl -sS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"create_milestone","arguments":{"title":"Bad date smoke","targetDate":"not-a-date","actor":"Ops"}}}')"
check_json "invalid date error" "$BAD_DATE" '.error.message | test("Invalid date")'

info "Documents"
DOCS="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"list_documents","arguments":{"projectKey":"ARK"}}}')"
check_json "list_documents has design pack" "$DOCS" '(.result.structuredContent.documents // []) | map(.path) | index("product/architecture.md") != null or (.result.content[0].text | contains("architecture.md"))'
READ="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"read_document","arguments":{"projectKey":"ARK","path":"product/architecture.md"}}}')"
check_json "read_document starts with Architecture" "$READ" '(.result.structuredContent.markdown // .result.content[0].text) | test("^# Architecture")'

info "REST"
check_json "REST projects" "$(curl -sfS --max-time 5 "$BASE/api/projects")" '.projects | type == "array" and length >= 1'
check_json "REST issues" "$(curl -sfS --max-time 5 "$BASE/api/issues?projectKey=ARK")" '.issues | type == "array"'
check_json "REST activity" "$(curl -sfS --max-time 5 "$BASE/api/activity?limit=10")" '.activities | type == "array"'
check_json "REST milestones" "$(curl -sfS --max-time 5 "$BASE/api/milestones")" '.milestones | type == "array"'

if [[ -n "$IDENT" || -n "$ISSUE_ID" ]]; then
  KEY="${ISSUE_ID:-$IDENT}"
  curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$KEY" '{
      jsonrpc:"2.0", id:90, method:"tools/call",
      params:{ name:"delete_issue", arguments:{ id:$id, identifier:$id, actor:"Ops" } }
    }')" >/dev/null || true
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  green "All $PASS checks passed."
  exit 0
else
  red "$FAIL failed, $PASS passed."
  exit 1
fi
