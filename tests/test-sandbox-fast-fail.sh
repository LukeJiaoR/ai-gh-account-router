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
printf 'call' >> "$FAKE_GH_CALLS"
printf ' <%s>' "$@" >> "$FAKE_GH_CALLS"
printf '\n' >> "$FAKE_GH_CALLS"
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "token" ]; then
  printf 'test-token\n'
  exit 0
fi
printf 'env <GH_TOKEN=%s> <GH_PROMPT_DISABLED=%s>\n' "${GH_TOKEN:-}" "${GH_PROMPT_DISABLED:-}" >> "$FAKE_GH_CALLS"
printf 'real-gh:%s\n' "$*"
EOF
chmod +x "$fake_gh"
printf '%s\n' "$fake_gh" > "$test_root/home/.config/ai-gh/real-gh-path"

run_wrapper() {
  local stdout_file="$test_root/stdout"
  local stderr_file="$test_root/stderr"
  set +e
  (cd "$test_root/repo" && env -u GH_AI_BYPASS HOME="$test_root/home" FAKE_GH_CALLS="$calls_file" "$@") > "$stdout_file" 2> "$stderr_file"
  command_status=$?
  set -e
  stdout="$(cat "$stdout_file")"
  stderr="$(cat "$stderr_file")"
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
  assert_equals "" "$stdout" "seatbelt stdout"
  assert_equals $'GH_EXTERNAL_EXECUTION_REQUIRED\ngh wrapper: Codex seatbelt blocks authenticated GitHub access.\ngh wrapper: retry this command with sandbox_permissions="require_escalated".' "$stderr" "seatbelt stderr contract"
  assert_real_gh_not_called
}

assert_seatbelt_blocked pr list
assert_seatbelt_blocked auth status

: > "$calls_file"
run_wrapper env CODEX_SANDBOX=seatbelt GH_AI_BYPASS=1 "$wrapper" pr list
assert_equals 77 "$command_status" "bypass exit code"
assert_equals "" "$stdout" "bypass stdout"
assert_contains "$stderr" "GH_EXTERNAL_EXECUTION_REQUIRED" "bypass marker"
assert_real_gh_not_called

for local_args in "" "version" "--version" "help" "--help" "pr --help" "auth --help"; do
  : > "$calls_file"
  if [ -z "$local_args" ]; then
    run_wrapper env CODEX_SANDBOX=seatbelt "$wrapper"
  else
    read -r -a args <<< "$local_args"
    run_wrapper env CODEX_SANDBOX=seatbelt "$wrapper" "${args[@]}"
  fi
  assert_equals 0 "$command_status" "local-only command exit code"
  assert_equals "real-gh:$local_args" "$stdout" "local-only command delegation"
  assert_equals "" "$stderr" "local-only command stderr"
  expected_call="call"
  if [ -n "$local_args" ]; then
    read -r -a expected_args <<< "$local_args"
    for arg in "${expected_args[@]}"; do
      expected_call="$expected_call <$arg>"
    done
  fi
  assert_equals "$expected_call" "$(head -n 1 "$calls_file")" "local-only command arguments"
done

for diagnostic in ai-account ai-status; do
  : > "$calls_file"
  run_wrapper env CODEX_SANDBOX=seatbelt "$wrapper" "$diagnostic"
  assert_equals 0 "$command_status" "$diagnostic exit code"
  assert_contains "$stdout" "real: $fake_gh" "$diagnostic output"
  assert_equals "" "$stderr" "$diagnostic stderr"
  assert_real_gh_not_called
done

: > "$calls_file"
run_wrapper env -u CODEX_SANDBOX CODEX_SANDBOX_NETWORK_DISABLED=1 "$wrapper" pr list
assert_equals 0 "$command_status" "external-style command exit code"
assert_equals "real-gh:pr list" "$stdout" "external-style command delegation"
assert_equals "" "$stderr" "external-style command stderr"
assert_equals $'call <auth> <token> <--user> <test-user>\ncall <pr> <list>\nenv <GH_TOKEN=test-token> <GH_PROMPT_DISABLED=1>' "$(cat "$calls_file")" "routed call sequence and environment"

echo "sandbox fast-fail checks passed"
