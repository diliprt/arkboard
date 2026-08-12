#!/usr/bin/env bash
# Smoke-test Arkboard local MCP/REST while the app is running.
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
    echo "$body" | head -c 500
    echo
    FAIL=$((FAIL + 1))
  fi
}

info "Health $BASE/health"
HEALTH="$(curl -sfS --max-time 3 "$BASE/health" || true)"
if [[ -z "$HEALTH" ]]; then
  red "FAIL  health (is Arkboard.app running? launch via ./scripts/run.sh)"
  exit 1
fi
check_json "health" "$HEALTH" '.name == "Arkboard"'

info "REST GET /api/projects"
PROJECTS="$(curl -sfS --max-time 5 "$BASE/api/projects")"
check_json "REST list projects" "$PROJECTS" '.projects | type == "array" and length >= 1'

info "MCP tools/list"
TOOLS="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')"
check_json "tools/list" "$TOOLS" '.result.tools | length >= 6'
check_json "tools include update_issue" "$TOOLS" '[.result.tools[].name] | index("update_issue") != null'
check_json "tools include list_activity" "$TOOLS" '[.result.tools[].name] | index("list_activity") != null'

TITLE="Smoke $(date +%Y%m%d-%H%M%S)"
info "MCP create_issue with actor ($TITLE)"
CREATE="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg t "$TITLE" '{
    jsonrpc:"2.0", id:2, method:"tools/call",
    params:{
      name:"create_issue",
      arguments:{ projectKey:"ARK", title:$t, status:"todo", priority:"low", labels:["smoke"], actor:"Ops" }
    }
  }')")"
check_json "create_issue" "$CREATE" '.result.structuredContent.title == "'"$TITLE"'" or (.result.content[0].text | contains("'"$TITLE"'"))'

IDENT="$(echo "$CREATE" | jq -r '.result.structuredContent.identifier // empty')"
ISSUE_ID="$(echo "$CREATE" | jq -r '.result.structuredContent.id // empty')"
if [[ -z "$IDENT" ]]; then
  IDENT="$(echo "$CREATE" | jq -r '.result.content[0].text' | jq -r '.identifier // empty' 2>/dev/null || true)"
fi
if [[ -z "$ISSUE_ID" ]]; then
  ISSUE_ID="$(echo "$CREATE" | jq -r '.result.content[0].text' | jq -r '.id // empty' 2>/dev/null || true)"
fi
info "Created identifier: ${IDENT:-unknown}"

info "MCP list_issues"
LIST="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_issues","arguments":{"projectKey":"ARK","query":"Smoke"}}}')"
check_json "list_issues" "$LIST" '.result.structuredContent.issues | length >= 1 or (.result.content[0].text | contains("Smoke"))'

if [[ -n "$IDENT" ]]; then
  info "MCP get_issue ($IDENT)"
  GET="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg ident "$IDENT" '{
      jsonrpc:"2.0", id:4, method:"tools/call",
      params:{ name:"get_issue", arguments:{ identifier:$ident } }
    }')")"
  check_json "get_issue" "$GET" '.result.structuredContent.identifier == "'"$IDENT"'" or (.result.content[0].text | contains("'"$IDENT"'"))'
fi

if [[ -n "$IDENT" || -n "$ISSUE_ID" ]]; then
  info "MCP update_issue (status -> in_progress, actor Product)"
  if [[ -n "$ISSUE_ID" ]]; then
    UPD_ARGS="$(jq -n --arg id "$ISSUE_ID" '{id:$id, status:"in_progress", actor:"Product"}')"
  else
    UPD_ARGS="$(jq -n --arg ident "$IDENT" '{identifier:$ident, status:"in_progress", actor:"Product"}')"
  fi
  UPDATE="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --argjson args "$UPD_ARGS" '{
      jsonrpc:"2.0", id:5, method:"tools/call",
      params:{ name:"update_issue", arguments:$args }
    }')")"
  check_json "update_issue" "$UPDATE" '.result.structuredContent.status == "in_progress" or (.result.content[0].text | contains("in_progress"))'
fi

info "MCP list_activity"
ACT="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"list_activity","arguments":{"limit":20,"projectKey":"ARK"}}}')"
check_json "list_activity" "$ACT" '.result.structuredContent.activities | type == "array" and length >= 1 or (.result.content[0].text | contains("activities"))'
check_json "list_activity has Ops actor" "$ACT" '(.result.structuredContent.activities // []) | map(.actor) | index("Ops") != null or (.result.content[0].text | contains("Ops"))'

info "REST GET /api/issues"
REST="$(curl -sfS --max-time 5 "$BASE/api/issues?projectKey=ARK")"
check_json "REST list issues" "$REST" '.issues | type == "array"'

info "REST GET /api/activity"
REST_ACT="$(curl -sfS --max-time 5 "$BASE/api/activity?limit=10")"
check_json "REST list activity" "$REST_ACT" '.activities | type == "array"'


info "MCP list_milestones"
MS="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"list_milestones","arguments":{}}}')"
check_json "list_milestones" "$MS" '.result.structuredContent.milestones | type == "array" and length >= 1 or (.result.content[0].text | contains("milestones"))'
check_json "tools include list_milestones" "$TOOLS" '[.result.tools[].name] | index("list_milestones") != null'
check_json "tools include create_milestone" "$TOOLS" '[.result.tools[].name] | index("create_milestone") != null'

MS_TITLE="Smoke Milestone $(date +%Y%m%d-%H%M%S)"
info "MCP create_milestone ($MS_TITLE)"
MSC="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg t "$MS_TITLE" '{
    jsonrpc:"2.0", id:9, method:"tools/call",
    params:{
      name:"create_milestone",
      arguments:{ title:$t, projectKey:"ARK", status:"planned", targetDate:(now | strftime("%Y-%m-%d")), actor:"Product", description:"smoke milestone" }
    }
  }')")"
check_json "create_milestone" "$MSC" '.result.structuredContent.title == "'"$MS_TITLE"'" or (.result.content[0].text | contains("'"$MS_TITLE"'"))'
MS_ID="$(echo "$MSC" | jq -r '.result.structuredContent.id // empty')"
if [[ -z "$MS_ID" ]]; then
  MS_ID="$(echo "$MSC" | jq -r '.result.content[0].text' | jq -r '.id // empty' 2>/dev/null || true)"
fi

if [[ -n "$MS_ID" ]]; then
  info "MCP update_milestone ($MS_ID -> in_progress)"
  MSU="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg id "$MS_ID" '{
      jsonrpc:"2.0", id:10, method:"tools/call",
      params:{ name:"update_milestone", arguments:{ id:$id, status:"in_progress", actor:"Ops" } }
    }')")"
  check_json "update_milestone" "$MSU" '.result.structuredContent.status == "in_progress" or (.result.content[0].text | contains("in_progress"))'
fi

if [[ -n "$IDENT" ]]; then
  info "MCP list_bot_thread ($IDENT)"
  THREAD="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg ident "$IDENT" '{
      jsonrpc:"2.0", id:11, method:"tools/call",
      params:{ name:"list_bot_thread", arguments:{ identifier:$ident } }
    }')")"
  check_json "list_bot_thread" "$THREAD" '.result.structuredContent.issue != null or (.result.content[0].text | contains("issue"))'
fi

info "REST GET /api/milestones"
REST_MS="$(curl -sfS --max-time 5 "$BASE/api/milestones")"
check_json "REST list milestones" "$REST_MS" '.milestones | type == "array"'

# Duplicate labels must succeed (dedupe), including feature+bug together.
if [[ -n "$IDENT" || -n "$ISSUE_ID" ]]; then
  info "MCP update_issue with duplicate labels"
  if [[ -n "$ISSUE_ID" ]]; then
    DUP_ARGS="$(jq -n --arg id "$ISSUE_ID" '{id:$id, labels:["feature","feature","bug"," Feature "], actor:"Comms"}')"
  else
    DUP_ARGS="$(jq -n --arg ident "$IDENT" '{identifier:$ident, labels:["feature","feature","bug"," Feature "], actor:"Comms"}')"
  fi
  DUP="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --argjson args "$DUP_ARGS" '{
      jsonrpc:"2.0", id:12, method:"tools/call",
      params:{ name:"update_issue", arguments:$args }
    }')")"
  check_json "update_issue duplicate labels succeed" "$DUP" '(.error | not) and ((.result.structuredContent.labels // []) | map(ascii_downcase) | unique | sort == ["bug","feature"] or (.result.content[0].text | test("feature") and test("bug")))'
fi

# Multi-mention comments emit one activity per distinct target.
if [[ -n "$IDENT" || -n "$ISSUE_ID" ]]; then
  info "MCP add_comment multi-mention @Ops @Comms"
  if [[ -n "$ISSUE_ID" ]]; then
    MM_ARGS="$(jq -n --arg id "$ISSUE_ID" '{issueId:$id, body:"@Ops @Comms please both review multi-mention smoke", actor:"Product"}')"
  else
    MM_ARGS="$(jq -n --arg ident "$IDENT" '{identifier:$ident, body:"@Ops @Comms please both review multi-mention smoke", actor:"Product"}')"
  fi
  MM="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --argjson args "$MM_ARGS" '{
      jsonrpc:"2.0", id:16, method:"tools/call",
      params:{ name:"add_comment", arguments:$args }
    }')")"
  check_json "add_comment multi-mention" "$MM" '(.error | not) and ((.result.structuredContent.body // .result.content[0].text) | test("@Ops") and test("@Comms"))'
  MM_ACT="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"list_activity","arguments":{"limit":30,"projectKey":"ARK"}}}')"
  check_json "activity has Ops target from multi-mention" "$MM_ACT" '([(.result.structuredContent.activities // [])[] | select(.summary|test("multi-mention"))] | map(.targetActor) | unique | sort) | (index("Ops") != null and index("Comms") != null) or (.result.content[0].text | test("→ Ops") and test("→ Comms"))'
fi

info "MCP add_comment empty body must error"
EMPTY_COMMENT="$(curl -sS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg id "${ISSUE_ID:-}" --arg ident "${IDENT:-ARK-1}" '{
    jsonrpc:"2.0", id:13, method:"tools/call",
    params:{
      name:"add_comment",
      arguments: (if $id != "" then {issueId:$id, body:"   ", actor:"Ops"} else {identifier:$ident, body:"   ", actor:"Ops"} end)
    }
  }')")"
check_json "empty comment error" "$EMPTY_COMMENT" '.error.message | test("Comment cannot be empty")'

info "MCP update_issue invalid status must error"
BAD_STATUS="$(curl -sS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg id "${ISSUE_ID:-}" --arg ident "${IDENT:-ARK-1}" '{
    jsonrpc:"2.0", id:14, method:"tools/call",
    params:{
      name:"update_issue",
      arguments: (if $id != "" then {id:$id, status:"nope", title:"should-not-apply", actor:"Ops"} else {identifier:$ident, status:"nope", title:"should-not-apply", actor:"Ops"} end)
    }
  }')")"
check_json "invalid status error" "$BAD_STATUS" '.error.message | test("Invalid status")'

info "MCP create_milestone invalid date must error"
BAD_DATE="$(curl -sS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc":"2.0","id":15,"method":"tools/call",
    "params":{"name":"create_milestone","arguments":{"title":"Bad date smoke","targetDate":"not-a-date","actor":"Ops"}}
  }')"
check_json "invalid milestone date error" "$BAD_DATE" '.error.message | test("Invalid date")'

# Cancel the issue this run created so overnight smokes do not clutter forever.
if [[ "$FAIL" -eq 0 && ( -n "$IDENT" || -n "$ISSUE_ID" ) ]]; then
  info "MCP update_issue (cancel smoke issue)"
  if [[ -n "$ISSUE_ID" ]]; then
    CANCEL_ARGS="$(jq -n --arg id "$ISSUE_ID" '{id:$id, status:"canceled", actor:"Ops"}')"
  else
    CANCEL_ARGS="$(jq -n --arg ident "$IDENT" '{identifier:$ident, status:"canceled", actor:"Ops"}')"
  fi
  CANCEL="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --argjson args "$CANCEL_ARGS" '{
      jsonrpc:"2.0", id:6, method:"tools/call",
      params:{ name:"update_issue", arguments:$args }
    }')")"
  check_json "cancel smoke issue" "$CANCEL" '.result.structuredContent.status == "canceled" or (.result.content[0].text | contains("canceled"))'
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  green "All $PASS checks passed."
  exit 0
else
  red "$FAIL failed, $PASS passed."
  exit 1
fi
