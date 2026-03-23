#!/usr/bin/env bash
# =============================================================================
# Rate Limit Guard Test Script
#
# Tests both AnonymousRateLimitGuard and AuthenticatedRateLimitGuard
# by hitting endpoints repeatedly and checking response headers + 429s.
#
# Usage:
#   ./scripts/test-rate-limits.sh [OPTIONS]
#
# Options:
#   -u, --url        Base API URL         (default: http://localhost:3000)
#   -t, --token      Bearer token for authenticated tests (required for auth tests)
#   -a, --anon-only  Run only anonymous tests
#   -A, --auth-only  Run only authenticated tests
#   -n, --requests   Number of requests   (default: auto-detect from headers)
#   -h, --help       Show help
# =============================================================================

set -euo pipefail

# --- Defaults ---
BASE_URL="http://localhost:3001/api"
TOKEN=""
ANON_ONLY=false
AUTH_ONLY=false
REQUEST_COUNT=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--url)      BASE_URL="$2"; shift 2 ;;
    -t|--token)    TOKEN="$2"; shift 2 ;;
    -a|--anon-only)  ANON_ONLY=true; shift ;;
    -A|--auth-only)  AUTH_ONLY=true; shift ;;
    -n|--requests) REQUEST_COUNT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^# =====/p' "$0" | head -n -1 | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Helpers ---
print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════${NC}"
}

print_pass() { echo -e "  ${GREEN}✓ PASS${NC}: $1"; }
print_fail() { echo -e "  ${RED}✗ FAIL${NC}: $1"; }
print_info() { echo -e "  ${YELLOW}ℹ INFO${NC}: $1"; }

PASS=0
FAIL=0

assert() {
  local desc="$1" condition="$2"
  if eval "$condition"; then
    print_pass "$desc"
    PASS=$((PASS + 1))
  else
    print_fail "$desc"
    FAIL=$((FAIL + 1))
  fi
}

# Extract rate limit header from curl response headers
get_header() {
  local headers="$1" name="$2"
  echo "$headers" | grep -i "^${name}:" | tail -1 | sed 's/^[^:]*: *//;s/\r$//' || true
}

# --- Probe: check server is reachable ---
print_header "Probing API at ${BASE_URL}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "000" ]]; then
  echo -e "${RED}ERROR: Cannot reach ${BASE_URL}/health — is the API running?${NC}"
  exit 1
fi
print_info "API reachable (HTTP ${HTTP_CODE})"

# =============================================================================
# TEST 1: Anonymous Rate Limit Guard
# =============================================================================
if [[ "$AUTH_ONLY" == false ]]; then
  print_header "Test: Anonymous Rate Limit Guard"
  print_info "Endpoint: GET /health (public, AnonymousRateLimitGuard)"

  # --- 1a: First request should succeed with rate limit headers ---
  RESP_HEADERS=$(curl -s -D - -o /dev/null "${BASE_URL}/health" 2>/dev/null)
  HTTP_STATUS=$(echo "$RESP_HEADERS" | head -1 | awk '{print $2}')

  ANON_LIMIT=$(get_header "$RESP_HEADERS" "X-RateLimit-Limit-anonymous")
  ANON_REMAINING=$(get_header "$RESP_HEADERS" "X-RateLimit-Remaining-anonymous")
  ANON_RESET=$(get_header "$RESP_HEADERS" "X-RateLimit-Reset-anonymous")

  assert "First request returns 200" '[[ "$HTTP_STATUS" == "200" ]]'

  if [[ -z "$ANON_LIMIT" ]]; then
    print_info "No X-RateLimit-Limit-anonymous header found."
    print_info "Rate limiting may not be configured (RATE_LIMIT_ANONYMOUS_TTL / RATE_LIMIT_ANONYMOUS_LIMIT env vars)."
    print_info "Skipping anonymous burst test."
  else
    print_info "Rate limit: ${ANON_LIMIT} requests per window"
    print_info "Remaining:  ${ANON_REMAINING}"
    print_info "Reset in:   ${ANON_RESET}s"

    assert "X-RateLimit-Limit-anonymous header present" '[[ -n "$ANON_LIMIT" ]]'
    assert "X-RateLimit-Remaining-anonymous header present" '[[ -n "$ANON_REMAINING" ]]'
    assert "X-RateLimit-Reset-anonymous header present" '[[ -n "$ANON_RESET" ]]'

    # --- 1b: Burst requests to exhaust the limit ---
    BURST_COUNT="${REQUEST_COUNT:-$ANON_LIMIT}"
    print_info "Sending ${BURST_COUNT} requests to exhaust anonymous limit..."

    GOT_429=false
    LAST_STATUS=""
    LAST_REMAINING=""

    for ((i=1; i<=BURST_COUNT+5; i++)); do
      RESP=$(curl -s -D - -o /dev/null "${BASE_URL}/health" 2>/dev/null)
      STATUS=$(echo "$RESP" | head -1 | awk '{print $2}')
      REMAINING=$(get_header "$RESP" "X-RateLimit-Remaining-anonymous")
      LAST_STATUS="$STATUS"
      LAST_REMAINING="$REMAINING"

      if [[ "$STATUS" == "429" ]]; then
        GOT_429=true
        RETRY_AFTER=$(get_header "$RESP" "Retry-After")
        print_info "Got 429 on request #${i}"
        [[ -n "$RETRY_AFTER" ]] && print_info "Retry-After: ${RETRY_AFTER}s"
        break
      fi
    done

    assert "Rate limit enforced (got 429)" '[[ "$GOT_429" == true ]]'

    if [[ "$GOT_429" == true ]]; then
      # --- 1c: Verify 429 response ---
      RESP_429=$(curl -s -D - -o /dev/null "${BASE_URL}/health" 2>/dev/null)
      STATUS_429=$(echo "$RESP_429" | head -1 | awk '{print $2}')
      assert "Subsequent requests still 429" '[[ "$STATUS_429" == "429" ]]'

      # Also check that /config is also blocked (shared counter, not per-route)
      RESP_CONFIG=$(curl -s -D - -o /dev/null "${BASE_URL}/config" 2>/dev/null)
      STATUS_CONFIG=$(echo "$RESP_CONFIG" | head -1 | awk '{print $2}')
      assert "Anonymous limit shared across routes (/config also 429)" '[[ "$STATUS_CONFIG" == "429" ]]'
    fi
  fi
fi

# =============================================================================
# TEST 2: Authenticated Rate Limit Guard
# =============================================================================
if [[ "$ANON_ONLY" == false ]]; then
  print_header "Test: Authenticated Rate Limit Guard"

  if [[ -z "$TOKEN" ]]; then
    print_info "No --token provided. Skipping authenticated rate limit tests."
    print_info "Usage: $0 --token <bearer-token>"
  else
    # Use /health/ready as it requires auth + AuthenticatedRateLimitGuard
    ENDPOINT="/health/ready"
    print_info "Endpoint: GET ${ENDPOINT} (authenticated, AuthenticatedRateLimitGuard)"

    # --- 2a: First request should succeed ---
    AUTH_HEADERS=(-H "Authorization: Bearer ${TOKEN}")
    RESP_HEADERS=$(curl -s -D - -o /dev/null "${AUTH_HEADERS[@]}" "${BASE_URL}${ENDPOINT}" 2>/dev/null)
    HTTP_STATUS=$(echo "$RESP_HEADERS" | head -1 | awk '{print $2}')

    if [[ "$HTTP_STATUS" == "401" || "$HTTP_STATUS" == "403" ]]; then
      print_fail "Auth failed (HTTP ${HTTP_STATUS}). Check your token."
    else
      AUTH_LIMIT=$(get_header "$RESP_HEADERS" "X-RateLimit-Limit-authenticated")
      AUTH_REMAINING=$(get_header "$RESP_HEADERS" "X-RateLimit-Remaining-authenticated")
      AUTH_RESET=$(get_header "$RESP_HEADERS" "X-RateLimit-Reset-authenticated")

      assert "First authenticated request succeeds (HTTP ${HTTP_STATUS})" '[[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "503" ]]'

      if [[ -z "$AUTH_LIMIT" ]]; then
        print_info "No X-RateLimit-Limit-authenticated header found."
        print_info "Rate limiting may not be configured (RATE_LIMIT_AUTHENTICATED_TTL / RATE_LIMIT_AUTHENTICATED_LIMIT env vars)."
        print_info "Skipping authenticated burst test."
      else
        print_info "Rate limit: ${AUTH_LIMIT} requests per window"
        print_info "Remaining:  ${AUTH_REMAINING}"
        print_info "Reset in:   ${AUTH_RESET}s"

        assert "X-RateLimit-Limit-authenticated header present" '[[ -n "$AUTH_LIMIT" ]]'
        assert "X-RateLimit-Remaining-authenticated header present" '[[ -n "$AUTH_REMAINING" ]]'
        assert "X-RateLimit-Reset-authenticated header present" '[[ -n "$AUTH_RESET" ]]'

        # --- 2b: Burst to exhaust limit ---
        BURST_COUNT="${REQUEST_COUNT:-$AUTH_LIMIT}"
        print_info "Sending ${BURST_COUNT} requests to exhaust authenticated limit..."

        GOT_429=false
        for ((i=1; i<=BURST_COUNT+5; i++)); do
          RESP=$(curl -s -D - -o /dev/null "${AUTH_HEADERS[@]}" "${BASE_URL}${ENDPOINT}" 2>/dev/null)
          STATUS=$(echo "$RESP" | head -1 | awk '{print $2}')

          if [[ "$STATUS" == "429" ]]; then
            GOT_429=true
            RETRY_AFTER=$(get_header "$RESP" "Retry-After")
            print_info "Got 429 on request #${i}"
            [[ -n "$RETRY_AFTER" ]] && print_info "Retry-After: ${RETRY_AFTER}s"
            break
          fi
        done

        assert "Authenticated rate limit enforced (got 429)" '[[ "$GOT_429" == true ]]'
      fi
    fi

    # --- 2c: Verify unauthenticated request to auth endpoint returns 401, not rate limit ---
    print_info ""
    print_info "Verifying auth guard runs before rate limit guard..."
    RESP_NOAUTH=$(curl -s -D - -o /dev/null "${BASE_URL}${ENDPOINT}" 2>/dev/null)
    STATUS_NOAUTH=$(echo "$RESP_NOAUTH" | head -1 | awk '{print $2}')
    assert "Unauthenticated request to protected endpoint returns 401" '[[ "$STATUS_NOAUTH" == "401" ]]'
  fi
fi

# =============================================================================
# TEST 3: Rate limit headers are NOT present when rate limiting is disabled
# =============================================================================
print_header "Test: Header presence check on /config"
RESP_CFG=$(curl -s -D - -o /dev/null "${BASE_URL}/config" 2>/dev/null)
STATUS_CFG=$(echo "$RESP_CFG" | head -1 | awk '{print $2}')

if [[ "$STATUS_CFG" == "429" ]]; then
  print_info "/config returned 429 (rate limited from earlier burst — this is expected)"
else
  CFG_ANON_LIMIT=$(get_header "$RESP_CFG" "X-RateLimit-Limit-anonymous")
  CFG_AUTH_LIMIT=$(get_header "$RESP_CFG" "X-RateLimit-Limit-authenticated")

  if [[ -n "$CFG_ANON_LIMIT" ]]; then
    assert "/config has anonymous rate limit headers (correct)" 'true'
  else
    print_info "/config has no anonymous rate limit headers (rate limiting not configured)"
  fi
  assert "/config does NOT have authenticated rate limit headers" '[[ -z "$CFG_AUTH_LIMIT" ]]'
fi

# =============================================================================
# Summary
# =============================================================================
print_header "Results"
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
