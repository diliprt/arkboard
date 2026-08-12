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
