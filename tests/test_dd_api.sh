#!/usr/bin/env bash
# Behavioral tests for dd-api against a stub DefectDojo.
#
# Deliberately dependency free (bash, curl, python3) so it runs identically on
# a laptop and in CI with nothing to install.
#
# Run: tests/test_dd_api.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DD_API="$REPO_ROOT/plugins/connect/bin/dd-api"
STUB="$REPO_ROOT/tests/stub_dojo.py"

VALID_TOKEN="0123456789abcdef0123456789abcdef01234567"
WRONG_TOKEN="ffffffffffffffffffffffffffffffffffffffff"

PASS=0
FAIL=0
STUB_PID=""
WORK_DIR="$(mktemp -d)"

stop_stub() {
  if [ -n "$STUB_PID" ]; then
    kill "$STUB_PID" 2>/dev/null
    wait "$STUB_PID" 2>/dev/null
    STUB_PID=""
  fi
}

cleanup() {
  stop_stub
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

start_stub() {
  local mode="$1"
  stop_stub
  PORT="$(free_port)"
  python3 "$STUB" "$PORT" "$mode" &
  STUB_PID=$!
  export DD_BASE_URL="http://127.0.0.1:$PORT"
  for _ in $(seq 1 50); do
    curl -sf -o /dev/null "$DD_BASE_URL/api/v2/user_profile/" -H "Authorization: Token $VALID_TOKEN" && break
    curl -s -o /dev/null "$DD_BASE_URL/" && break
    sleep 0.1
  done
}

# Isolate all state: never touch the developer's real ~/.defectdojo
export DD_CONFIG_FILE="$WORK_DIR/config.json"
export DD_CACHE_DIR="$WORK_DIR/cache"

write_config() {
  printf '{\n  "url": "%s",\n  "token": "%s"\n}\n' "$1" "$2" > "$DD_CONFIG_FILE"
  chmod 600 "$DD_CONFIG_FILE"
}

clear_cache() { rm -rf "$DD_CACHE_DIR"; }

expect_exit() {
  local desc="$1" want="$2"; shift 2
  local out got
  out="$("$@" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then ok "$desc"
  else bad "$desc" "expected exit $want, got $got. Output: $(printf '%s' "$out" | head -3 | tr '\n' ' ')"; fi
}

expect_contains() {
  local desc="$1" needle="$2"; shift 2
  local out
  out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -qF "$needle"; then ok "$desc"
  else bad "$desc" "expected output to contain '$needle'. Got: $(printf '%s' "$out" | head -5 | tr '\n' ' ')"; fi
}

expect_not_contains() {
  local desc="$1" needle="$2"; shift 2
  local out
  out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -qF "$needle"; then
    bad "$desc" "output unexpectedly contained '$needle'"
  else ok "$desc"; fi
}

printf '\n== Pro instance ==\n'
start_stub pro
write_config "$DD_BASE_URL" "$VALID_TOKEN"
clear_cache
unset DD_API_TOKEN

expect_exit      "whoami succeeds against Pro"                0 "$DD_API" whoami
expect_contains  "whoami returns the user profile"            "tester" "$DD_API" whoami
expect_exit      "version succeeds"                           0 "$DD_API" version
expect_contains  "get passes through query strings"           "SQL Injection" "$DD_API" get "/api/v2/findings/?limit=5"
expect_exit      "close-finding succeeds"                     0 "$DD_API" close-finding 4711
expect_exit      "verify-finding succeeds"                    0 "$DD_API" verify-finding 4711
expect_exit      "note succeeds"                              0 "$DD_API" note 4711 "checked by tests"
expect_contains  "close-finding --note posts the note first"  "recorded" "$DD_API" close-finding 4711 --note "fixed in 1.2.3"

printf '\n== Credential handling ==\n'
expect_contains  "config reports the token source"            "config.json" "$DD_API" config
expect_not_contains "config never prints the token"           "$VALID_TOKEN" "$DD_API" config
expect_not_contains "verbose output never prints the token"   "$VALID_TOKEN" "$DD_API" --verbose whoami

# Environment variable must win over the config file. Point the file at a
# deliberately wrong token: success proves the environment took priority.
write_config "$DD_BASE_URL" "$WRONG_TOKEN"
clear_cache
expect_exit      "DD_API_TOKEN overrides the config file"     0 env DD_API_TOKEN="$VALID_TOKEN" "$DD_API" whoami
expect_contains  "config names the environment as the source" "environment variable" env DD_API_TOKEN="$VALID_TOKEN" "$DD_API" config

# ...and with no override, the wrong token in the file must fail with exit 4.
expect_exit      "bad token exits 4"                          4 "$DD_API" whoami
expect_contains  "bad token explains token expiry"            "can expire" "$DD_API" whoami

rm -f "$DD_CONFIG_FILE"
clear_cache
expect_exit      "missing configuration exits 3"              3 env -u DD_BASE_URL -u DD_API_TOKEN "$DD_API" whoami

printf '\n== Edition gate ==\n'
start_stub oss
write_config "$DD_BASE_URL" "$VALID_TOKEN"
clear_cache
expect_exit      "open source instance exits 5"               5 "$DD_API" whoami
expect_contains  "open source refusal names Pro"              "requires DefectDojo Pro" "$DD_API" whoami
expect_contains  "open source refusal is explicit"            "not a DefectDojo Pro instance" "$DD_API" get "/api/v2/findings/"
expect_exit      "import is blocked on open source"           5 "$DD_API" import --file "$STUB" --scan-type "Generic Findings Import"

start_stub expired
write_config "$DD_BASE_URL" "$VALID_TOKEN"
clear_cache
expect_exit      "401 during the edition probe reports auth, not edition" 4 "$DD_API" whoami

printf '\n== Import handling ==\n'
start_stub pro
write_config "$DD_BASE_URL" "$VALID_TOKEN"
clear_cache
printf '{"findings": []}' > "$WORK_DIR/scan.json"
expect_exit      "synchronous import succeeds"                0 "$DD_API" import --file "$WORK_DIR/scan.json" --scan-type "Generic Findings Import"
expect_not_contains "synchronous import does not wait"        "waiting for import" "$DD_API" import --file "$WORK_DIR/scan.json" --scan-type "Generic Findings Import"
expect_exit      "import without a file is a usage error"     2 "$DD_API" import --scan-type "Generic Findings Import"

start_stub pro-async
write_config "$DD_BASE_URL" "$VALID_TOKEN"
clear_cache
expect_contains  "background import is detected from the response" "background processing" \
                 "$DD_API" import --file "$WORK_DIR/scan.json" --scan-type "Generic Findings Import"
expect_contains  "background import polls to completion"      "import finished" \
                 "$DD_API" import --file "$WORK_DIR/scan.json" --scan-type "Generic Findings Import"
expect_exit      "background import returns 0 once processed" 0 \
                 "$DD_API" import --file "$WORK_DIR/scan.json" --scan-type "Generic Findings Import"
expect_not_contains "--no-poll returns without waiting"       "waiting for import" \
                 "$DD_API" import --file "$WORK_DIR/scan.json" --scan-type "Generic Findings Import" --no-poll

start_stub pro-failing
write_config "$DD_BASE_URL" "$VALID_TOKEN"
clear_cache
expect_exit      "failed background import exits non-zero"    6 \
                 "$DD_API" import --file "$WORK_DIR/scan.json" --scan-type "Generic Findings Import"

printf '\n== Usage ==\n'
start_stub pro
write_config "$DD_BASE_URL" "$VALID_TOKEN"
clear_cache
expect_exit      "help exits 0"                               0 "$DD_API" --help
expect_exit      "unknown command is a usage error"           2 "$DD_API" frobnicate
expect_exit      "get without a path is a usage error"        2 "$DD_API" get

printf '\n%s passed, %s failed\n\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
