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

info "MCP tools/list"
TOOLS="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')"
check_json "tools/list" "$TOOLS" '.result.tools | length >= 6'

TITLE="Smoke $(date +%Y%m%d-%H%M%S)"
info "MCP create_issue ($TITLE)"
CREATE="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg t "$TITLE" '{
    jsonrpc:"2.0", id:2, method:"tools/call",
    params:{
      name:"create_issue",
      arguments:{ projectKey:"ARK", title:$t, status:"todo", priority:"low", labels:["smoke"] }
    }
  }')")"
check_json "create_issue" "$CREATE" '.result.structuredContent.title == "'"$TITLE"'" or (.result.content[0].text | contains("'"$TITLE"'"))'

IDENT="$(echo "$CREATE" | jq -r '.result.structuredContent.identifier // empty')"
if [[ -z "$IDENT" ]]; then
  # Fallback: parse from text blob
  IDENT="$(echo "$CREATE" | jq -r '.result.content[0].text' | jq -r '.identifier // empty' 2>/dev/null || true)"
fi
info "Created identifier: ${IDENT:-unknown}"

info "MCP list_issues"
LIST="$(curl -sfS --max-time 5 -X POST "$BASE/mcp" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_issues","arguments":{"projectKey":"ARK","query":"Smoke"}}}')"
check_json "list_issues" "$LIST" '.result.structuredContent.issues | length >= 1 or (.result.content[0].text | contains("Smoke"))'

info "REST GET /api/issues"
REST="$(curl -sfS --max-time 5 "$BASE/api/issues?projectKey=ARK")"
check_json "REST list issues" "$REST" '.issues | type == "array"'

echo
if [[ "$FAIL" -eq 0 ]]; then
  green "All $PASS checks passed."
  exit 0
else
  red "$FAIL failed, $PASS passed."
  exit 1
fi
