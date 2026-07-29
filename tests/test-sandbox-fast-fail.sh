#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_root/bin/gh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/home/.config/ai-gh" "$test_root/repo"
git -C "$test_root/repo" init -q
printf 'test-user\n' > "$test_root/repo/.ai-gh-account"

fake_gh="$test_root/real-gh"
calls_file="$test_root/calls"

cat > "$fake_gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GH_CALLS"
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "token" ]; then
  printf 'test-token\n'
  exit 0
fi
printf 'real-gh:%s\n' "$*"
EOF
chmod +x "$fake_gh"
printf '%s\n' "$fake_gh" > "$test_root/home/.config/ai-gh/real-gh-path"

run_wrapper() {
  set +e
  output="$(cd "$test_root/repo" && env HOME="$test_root/home" FAKE_GH_CALLS="$calls_file" "$@" 2>&1)"
  command_status=$?
  set -e
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "$expected" != "$actual" ]; then
    echo "$message: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "$message: missing '$needle'" >&2
    exit 1
  fi
}

assert_real_gh_not_called() {
  if [ -s "$calls_file" ]; then
    echo "real gh was called unexpectedly: $(cat "$calls_file")" >&2
    exit 1
  fi
}

assert_seatbelt_blocked() {
  : > "$calls_file"
  run_wrapper env CODEX_SANDBOX=seatbelt "$wrapper" "$@"
  assert_equals 77 "$command_status" "seatbelt exit code"
  assert_contains "$output" "GH_EXTERNAL_EXECUTION_REQUIRED" "seatbelt marker"
  assert_contains "$output" 'sandbox_permissions="require_escalated"' "seatbelt retry guidance"
  assert_real_gh_not_called
}

assert_seatbelt_blocked pr list
assert_seatbelt_blocked auth status

: > "$calls_file"
run_wrapper env CODEX_SANDBOX=seatbelt GH_AI_BYPASS=1 "$wrapper" pr list
assert_equals 77 "$command_status" "bypass exit code"
assert_contains "$output" "GH_EXTERNAL_EXECUTION_REQUIRED" "bypass marker"
assert_real_gh_not_called

for local_args in "" "version" "--version" "help" "--help" "pr --help"; do
  : > "$calls_file"
  if [ -z "$local_args" ]; then
    run_wrapper env CODEX_SANDBOX=seatbelt "$wrapper"
  else
    read -r -a args <<< "$local_args"
    run_wrapper env CODEX_SANDBOX=seatbelt "$wrapper" "${args[@]}"
  fi
  assert_equals 0 "$command_status" "local-only command exit code"
  assert_contains "$output" "real-gh:" "local-only command delegation"
done

for diagnostic in ai-account ai-status; do
  : > "$calls_file"
  run_wrapper env CODEX_SANDBOX=seatbelt "$wrapper" "$diagnostic"
  assert_equals 0 "$command_status" "$diagnostic exit code"
  assert_contains "$output" "real: $fake_gh" "$diagnostic output"
  assert_real_gh_not_called
done

: > "$calls_file"
run_wrapper env -u CODEX_SANDBOX CODEX_SANDBOX_NETWORK_DISABLED=1 "$wrapper" pr list
assert_equals 0 "$command_status" "external-style command exit code"
assert_contains "$output" "real-gh:pr list" "external-style command delegation"
assert_contains "$(cat "$calls_file")" "auth token --user test-user" "routed token lookup"

echo "sandbox fast-fail checks passed"
