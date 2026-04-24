#!/usr/bin/env bash
# Smoke-test MyMeetings HTTP API (read-only by default; optional mutating tests).
# Requires: curl, python3 (for JSON); optional jq for human-readable token debug.
#
# Environment:
#   MYMEETINGS_BASE_URL          API base (default: http://localhost:5000)
#   MYMEETINGS_MEMBER_USERNAME   (default: testMember@mail.com)
#   MYMEETINGS_MEMBER_PASSWORD   (default: testMemberPass)
#   MYMEETINGS_ADMIN_USERNAME    (default: testAdmin@mail.com)
#   MYMEETINGS_ADMIN_PASSWORD    (default: testAdminPass)
#   MYMEETINGS_INCLUDE_MUTATING  set to 1 to run POST/PATCH/PUT/DELETE (changes data)
#   MYMEETINGS_CURL_INSECURE     set to 1 to pass curl -k (e.g. dev HTTPS)
#   MYMEETINGS_VERBOSE           set to 1 to print response bodies on failure
#
# See also: src/API/RequestExamples/*.http and README "Authenticate" section.

set -uo pipefail

BASE_URL="${MYMEETINGS_BASE_URL:-http://localhost:5000}"
MEMBER_USER="${MYMEETINGS_MEMBER_USERNAME:-testMember@mail.com}"
MEMBER_PASS="${MYMEETINGS_MEMBER_PASSWORD:-testMemberPass}"
ADMIN_USER="${MYMEETINGS_ADMIN_USERNAME:-testAdmin@mail.com}"
ADMIN_PASS="${MYMEETINGS_ADMIN_PASSWORD:-testAdminPass}"
INCLUDE_MUTATING="${MYMEETINGS_INCLUDE_MUTATING:-0}"
CURL_INSECURE="${MYMEETINGS_CURL_INSECURE:-0}"
VERBOSE="${MYMEETINGS_VERBOSE:-0}"

CURL=(curl -sS)
if [[ "$CURL_INSECURE" == "1" ]]; then
  CURL+=(-k)
fi

pass_count=0
fail_count=0

log_pass() { echo "[ OK ] $*"; pass_count=$((pass_count + 1)); }
log_fail() { echo "[FAIL] $*" >&2; fail_count=$((fail_count + 1)); }
log_info() { echo "       $*"; }

# --- JSON helpers (python3 required) -------------------------------------------------
# IdentityServer4 client (IdentityServerConfig) allows: all, openid, profile — include scope.
get_token() {
  local user="$1" pass="$2"
  local out code body bodyf tokf
  out="$(mktemp)" || { echo "mktemp failed" >&2; return 1; }
  # Use --data-urlencode for credentials so & and + in password do not break the form.
  code=$("${CURL[@]}" -sS -o "$out" -w "%{http_code}" -X POST "${BASE_URL}/connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=ro.client" \
    -d "client_secret=secret" \
    -d "scope=all openid profile" \
    --data-urlencode "username=$user" \
    --data-urlencode "password=$pass")
  body=$(<"$out")
  rm -f "$out" || true

  if [[ ! "$code" =~ ^(200|400)$ ]]; then
    echo "Token request failed: HTTP $code" >&2
    echo "Body (first 2000 chars): ${body:0:2000}" >&2
    return 1
  fi

  bodyf=$(mktemp) || return 1
  tokf=$(mktemp)  || { rm -f "$bodyf"; return 1; }
  printf '%s' "$body" > "$bodyf"

  local t
  t=""
  if python3 -c "import json, sys, pathlib
b, out = sys.argv[1], sys.argv[2]
try:
  d = json.loads(pathlib.Path(b).read_text(encoding='utf-8'))
except (ValueError, OSError) as e:
  sys.stderr.write('Invalid token response: ' + str(e) + '\n')
  raise SystemExit(1) from e
tok = d.get('access_token')
if tok:
  pathlib.Path(out).write_text(tok, encoding='ascii')
  raise SystemExit(0)
e = d.get('error', 'no_access_token')
ed = d.get('error_description') or ''
sys.stderr.write((e + ': ' + ed + '\n') if ed else (e + ' (keys: ' + str(list(d.keys())) + ')\n'))
raise SystemExit(1)
" "$bodyf" "$tokf"; then
    t=$(<"$tokf")
  fi
  rm -f "$bodyf" "$tokf" || true

  if [[ -n "$t" ]]; then
    printf '%s' "$t"
    return 0
  fi
  echo "Token request failed: HTTP $code" >&2
  echo "Body (first 2000 chars): ${body:0:2000}" >&2
  echo "Hint: use seed users (e.g. testMember@mail.com / testMemberPass from SeedDatabase.sql) or set MYMEETINGS_MEMBER_USERNAME." >&2
  return 1
}

first_meeting_id() {
  python3 -c "
import json,sys
a=json.load(sys.stdin)
if not isinstance(a, list) or not a:
  sys.exit(1)
m=a[0].get('meetingId') or a[0].get('MeetingId')
print(m) if m else sys.exit(1)
" 2>/dev/null
}

first_group_id() {
  python3 -c "
import json,sys
a=json.load(sys.stdin)
if not isinstance(a, list) or not a:
  sys.exit(1)
row=a[0]
m = row.get('id') or row.get('Id') or row.get('meetingGroupId') or row.get('MeetingGroupId')
if not m: sys.exit(1)
print(m)
" 2>/dev/null
}

# --- HTTP: print status code only ----------------------------------------------------
http_code() {
  local method="$1" path="$2" token="${3:-}"
  local auth=()
  if [[ -n "$token" ]]; then
    auth=(-H "Authorization: Bearer ${token}")
  fi
  case "$method" in
    GET)
      "${CURL[@]}" -o /tmp/mymeetings_body_$$.txt -w "%{http_code}" -X GET "${auth[@]}" "${BASE_URL}${path}" || true
      ;;
    POST|PUT|PATCH|DELETE)
      local body="${4:-}"
      local content=()
      if [[ -n "$body" ]]; then
        content=(-H "Content-Type: application/json" -d "$body")
      fi
      "${CURL[@]}" -o /tmp/mymeetings_body_$$.txt -w "%{http_code}" -X "$method" "${auth[@]}" "${content[@]}" "${BASE_URL}${path}" || true
      ;;
    *)
      echo 000
      return
      ;;
  esac
}

expect_code() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    log_pass "$name (HTTP $actual)"
  else
    log_fail "$name — expected $expected, got $actual"
    if [[ "$VERBOSE" == "1" ]] && [[ -f /tmp/mymeetings_body_$$.txt ]]; then
      log_info "$(head -c 2000 /tmp/mymeetings_body_$$.txt)"
    fi
  fi
  rm -f /tmp/mymeetings_body_$$.txt
}

# --- Main ---------------------------------------------------------------------------
echo "Base URL: $BASE_URL"
echo

code="$(http_code GET "/swagger/v1/swagger.json" "")"
rm -f /tmp/mymeetings_body_$$.txt
if [[ "$code" == "200" ]]; then log_pass "GET /swagger/v1/swagger.json (OpenAPI) (HTTP 200)"; else log_fail "GET /swagger/v1/swagger.json — $code (is the API running?)"; fi

if ! member_token="$(get_token "$MEMBER_USER" "$MEMBER_PASS")"; then
  echo "Failed to obtain member token. Check credentials and that IdentityServer is hosted at the same base URL."
  exit 1
fi
if ! admin_token="$(get_token "$ADMIN_USER" "$ADMIN_PASS")"; then
  echo "Failed to obtain admin token."
  exit 1
fi

# Member: user access & meetings
for path in \
  "/api/userAccess/authenticatedUser" \
  "/api/userAccess/authenticatedUser/permissions" \
  "/api/userAccess/emails" \
  "/api/meetings/meetings" \
  "/api/meetings/countries" \
  "/api/meetings/MeetingGroups" \
  "/api/meetings/MeetingGroups/all" \
  "/api/meetings/MeetingGroupProposals" \
  "/api/meetings/MeetingGroupProposals/all" \
  "/api/payments/priceListItems" \
  "/api/payments/payers/authenticated/subscription"
do
  c="$(http_code GET "$path" "$member_token")"
  expect_code "GET $path" 200 "$c"
done

# Sub-resources using first meeting id (if any)
meetings_json="$("${CURL[@]}" -H "Authorization: Bearer ${member_token}" "${BASE_URL}/api/meetings/meetings" 2>/dev/null || true)"
if mid="$(printf '%s' "$meetings_json" | first_meeting_id)"; then
  c="$(http_code GET "/api/meetings/meetings/${mid}" "$member_token")"
  expect_code "GET /api/meetings/meetings/{meetingId} (using seed meeting if present)" 200 "$c"
  c="$(http_code GET "/api/meetings/meetings/${mid}/attendees" "$member_token")"
  expect_code "GET /api/meetings/meetings/{meetingId}/attendees" 200 "$c"
  # First group id (MemberMeetingGroupDto uses "id" in JSON)
  if gid="$(printf '%s' "$("${CURL[@]}" -H "Authorization: Bearer ${member_token}" "${BASE_URL}/api/meetings/MeetingGroups" 2>/dev/null)" | first_group_id)"; then
    c="$(http_code GET "/api/meetings/MeetingGroups/${gid}" "$member_token")"
    expect_code "GET /api/meetings/MeetingGroups/{meetingGroupId}" 200 "$c"
  else
    log_info "SKIP GET /api/meetings/MeetingGroups/{id} (no group id in list)"
  fi
else
  log_info "SKIP GET /api/meetings/meetings/{meetingId}* — no meetings in database (empty list)"
fi

# Admin
c="$(http_code GET "/api/administration/meetingGroupProposals" "$admin_token")"
expect_code "GET /api/administration/meetingGroupProposals (admin)" 200 "$c"

# Optional mutating: registration POST, subscription POSTs, etc. (can fail on validation)
if [[ "$INCLUDE_MUTATING" == "1" ]]; then
  echo
  echo "--- MYMEETINGS_INCLUDE_MUTATING=1 (data-changing calls) ---"
  rnd="${RANDOM}_$(date +%s)"
  reg_body="{\"Login\":\"t${rnd}\",\"Password\":\"Pass#${rnd}9\",\"Email\":\"t${rnd}@example.com\",\"FirstName\":\"T\",\"LastName\":\"E\",\"ConfirmLink\":\"http://localhost/confirm\"}"
  c="$(http_code POST "/userAccess/UserRegistrations" "" "$reg_body")"
  expect_code "POST /userAccess/UserRegistrations (register)" 200 "$c"
  c="$(http_code POST "/api/payments/subscriptionPayments" "$member_token" "{\"paymentId\":\"00000000-0000-0000-0000-000000000000\"}")"
  log_info "POST /api/payments/subscriptionPayments (dummy id) → HTTP $c (often 4xx/5xx: no such payment)"
  c="$(http_code POST "/api/payments/subscriptionRenewals" "$member_token" "{\"paymentId\":\"00000000-0000-0000-0000-000000000000\"}")"
  log_info "POST /api/payments/subscriptionRenewals (dummy id) → HTTP $c"
  c="$(http_code POST "/api/payments/meetingFeePayments" "$member_token" "{\"meetingFeeId\":\"00000000-0000-0000-0000-000000000000\"}")"
  log_info "POST /api/payments/meetingFeePayments (dummy id) → HTTP $c"
else
  echo
  log_info "Mutating requests skipped. Set MYMEETINGS_INCLUDE_MUTATING=1 to attempt POST/PUT/PATCH/DELETE (may change data or fail with 4xx)"
fi

echo
echo "Done. Passed: $pass_count  Failed: $fail_count"
[[ "$fail_count" -eq 0 ]] || exit 1
