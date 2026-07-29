# GitHub CLI Sandbox Fast-Fail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the local `gh` wrapper fail predictably inside Codex seatbelt before network or Keychain access, while preserving local-only help and router diagnostics.

**Architecture:** Add a small command classifier near the top of `bin/gh`, before `GH_AI_BYPASS` and account-token lookup. When `CODEX_SANDBOX=seatbelt` and the command is not local-only, emit a stable marker to stderr and exit `77`; tests use a fake real `gh` binary to prove it was never invoked.

**Tech Stack:** Bash, GitHub CLI wrapper, shell integration tests, existing portable SKILL.md layout validation.

---

## File Map

- Create `tests/test-sandbox-fast-fail.sh`: isolated behavioral tests using a temporary HOME and fake real `gh`.
- Modify `bin/gh`: local-command classification and Codex seatbelt fail-fast guard.
- Modify `tests/test-skill-layout.sh`: require the marker in canonical and fallback instructions.
- Modify `agent-instructions/SKILL.md`: canonical retry and scope guidance.
- Modify `skills/github-account-router/SKILL.md`: byte-identical bundled copy of the canonical skill.
- Modify `agent-instructions/AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `CURSOR.md`, `OPENCLAW.md`: fallback guidance for the stable marker.
- Modify `README.md`: user-visible behavior and troubleshooting.
- Modify `RELEASE_NOTES.md`: unreleased wrapper behavior.

### Task 1: Add The Failing Wrapper Test

**Files:**
- Create: `tests/test-sandbox-fast-fail.sh`

- [ ] **Step 1: Write the isolated behavioral test**

Create `tests/test-sandbox-fast-fail.sh` with this complete content:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_root/bin/gh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/home/.config/ai-gh"

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
  output="$(env HOME="$test_root/home" FAKE_GH_CALLS="$calls_file" "$@" 2>&1)"
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
assert_contains "$(cat "$calls_file")" "auth token --user" "routed token lookup"

echo "sandbox fast-fail checks passed"
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x tests/test-sandbox-fast-fail.sh
```

Expected: `git status --short` shows `?? tests/test-sandbox-fast-fail.sh`.

- [ ] **Step 3: Run the test and verify RED**

Run:

```bash
bash tests/test-sandbox-fast-fail.sh
```

Expected: FAIL at the first `pr list` assertion because the current wrapper does not exit `77` or emit `GH_EXTERNAL_EXECUTION_REQUIRED`.

- [ ] **Step 4: Commit the failing regression test**

```bash
git add tests/test-sandbox-fast-fail.sh
git commit -m "test: reproduce sandboxed gh execution"
```

### Task 2: Implement The Minimal Seatbelt Guard

**Files:**
- Modify: `bin/gh:18-25`
- Test: `tests/test-sandbox-fast-fail.sh`

- [ ] **Step 1: Move command parsing before bypass and add classification**

Replace the current `GH_AI_BYPASS` block and command assignments with:

```bash
cmd="${1:-}"
subcmd="${2:-}"
local_only=0

case "$cmd" in
  ""|ai-account|ai-status|version|help|--version|--help)
    local_only=1
    ;;
esac

if [ "$local_only" -eq 0 ]; then
  for arg in "$@"; do
    if [ "$arg" = "--help" ]; then
      local_only=1
      break
    fi
  done
fi

if [ "${CODEX_SANDBOX:-}" = "seatbelt" ] && [ "$local_only" -eq 0 ]; then
  echo "GH_EXTERNAL_EXECUTION_REQUIRED" >&2
  echo "gh wrapper: Codex seatbelt blocks authenticated GitHub access." >&2
  echo 'gh wrapper: retry this command with sandbox_permissions="require_escalated".' >&2
  exit 77
fi

if [ "${GH_AI_BYPASS:-}" = "1" ]; then
  exec "$GH_REAL" "$@"
fi
```

Do not move the existing `ai-account`/`ai-status` handler or routing allowlist. The guard must remain before `GH_AI_BYPASS`.

- [ ] **Step 2: Run the focused test and verify GREEN**

Run:

```bash
bash tests/test-sandbox-fast-fail.sh
```

Expected: `sandbox fast-fail checks passed`.

- [ ] **Step 3: Run wrapper and layout regression checks**

Run:

```bash
bash -n bin/gh bin/ai-gh-init install.sh uninstall.sh tests/test-sandbox-fast-fail.sh tests/test-skill-layout.sh
bash tests/test-skill-layout.sh
```

Expected: shell syntax exits `0`; layout test prints `skill layout checks passed`.

- [ ] **Step 4: Commit the implementation**

```bash
git add bin/gh
git commit -m "feat: fail fast for sandboxed gh commands"
```

### Task 3: Publish The Error Contract

**Files:**
- Modify: `agent-instructions/SKILL.md`
- Modify: `skills/github-account-router/SKILL.md`
- Modify: `agent-instructions/AGENTS.md`
- Modify: `agent-instructions/CLAUDE.md`
- Modify: `agent-instructions/CODEX.md`
- Modify: `agent-instructions/CURSOR.md`
- Modify: `agent-instructions/OPENCLAW.md`
- Modify: `tests/test-skill-layout.sh`
- Modify: `README.md`
- Modify: `RELEASE_NOTES.md`

- [ ] **Step 1: Update the canonical skill sandbox section**

Add this paragraph after the Codex-style external execution paragraph in `agent-instructions/SKILL.md`:

```markdown
The installed wrapper fails non-local commands inside Codex seatbelt with exit code `77` and the marker `GH_EXTERNAL_EXECUTION_REQUIRED`. Treat that marker as a requirement to retry the same operation through approved external execution. Local `help`, `version`, `ai-account`, and `ai-status` commands remain available. The guard cannot be bypassed with `GH_AI_BYPASS=1`.
```

Replace the final Git-boundary sentence with:

```markdown
Use bypass only for diagnostics through approved external execution. This router controls `gh`, not any `git` command; sandbox rules still apply to Git metadata writes such as `git worktree remove`, `git worktree prune`, and branch deletion.
```

- [ ] **Step 2: Synchronize the bundled skill**

Run:

```bash
cp agent-instructions/SKILL.md skills/github-account-router/SKILL.md
cmp agent-instructions/SKILL.md skills/github-account-router/SKILL.md
```

Expected: `cmp` exits `0` with no output.

- [ ] **Step 3: Update every fallback instruction**

Add this exact paragraph near the existing sandbox/execution guidance in each of `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `CURSOR.md`, and `OPENCLAW.md`:

```markdown
If the wrapper exits `77` with `GH_EXTERNAL_EXECUTION_REQUIRED`, retry the same `gh` operation through approved external execution. Do not bypass the guard. It does not cover `git` commands or Git metadata writes.
```

- [ ] **Step 4: Extend the layout contract test**

Inside the existing template loop in `tests/test-skill-layout.sh`, add:

```bash
  grep -q "GH_EXTERNAL_EXECUTION_REQUIRED" "$template_path"
```

After the loop, add:

```bash
grep -q "GH_EXTERNAL_EXECUTION_REQUIRED" "$portable_skill"
grep -q "git worktree remove" "$portable_skill"
```

- [ ] **Step 5: Document wrapper behavior**

Add a `Sandbox fast-fail` subsection under `Agent usage` in `README.md` containing:

````markdown
### Sandbox fast-fail

Inside Codex seatbelt, network- or credential-dependent commands stop before real `gh` runs:

```text
GH_EXTERNAL_EXECUTION_REQUIRED
gh wrapper: Codex seatbelt blocks authenticated GitHub access.
gh wrapper: retry this command with sandbox_permissions="require_escalated".
```

The wrapper exits `77`. Retry the same command through approved external execution. Purely local help, version, and router diagnostic commands remain available. This behavior does not govern `git` commands; Git metadata writes may need their own sandbox approval.
````

- [ ] **Step 6: Add the release note**

Under `Unreleased` in `RELEASE_NOTES.md`, add:

```markdown
- Added deterministic Codex seatbelt detection: non-local `gh` commands now fail before network or Keychain access with exit `77` and `GH_EXTERNAL_EXECUTION_REQUIRED`.
- Kept local help, version, and router diagnostics available inside the sandbox, and documented that Git metadata writes remain outside router scope.
```

- [ ] **Step 7: Validate documentation and contracts**

Run:

```bash
bash tests/test-skill-layout.sh
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py agent-instructions
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/github-account-router
git diff --check
```

Expected: both skills report `Skill is valid!`, layout checks pass, and `git diff --check` produces no output.

- [ ] **Step 8: Commit documentation and contract updates**

```bash
git add README.md RELEASE_NOTES.md agent-instructions skills/github-account-router/SKILL.md tests/test-skill-layout.sh
git commit -m "docs: publish gh sandbox retry contract"
```

### Task 4: Install And Verify The Real Local Wrapper

**Files:**
- Install from: `bin/gh`
- Install to: `~/.local/bin/gh`
- Install skill to: `~/.codex/skills/github-account-router/SKILL.md`

- [ ] **Step 1: Run the complete repository verification suite**

Run:

```bash
set -e
bash tests/test-sandbox-fast-fail.sh
bash tests/test-skill-layout.sh
bash -n bin/gh bin/ai-gh-init install.sh uninstall.sh tests/test-sandbox-fast-fail.sh tests/test-skill-layout.sh
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py agent-instructions
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/github-account-router
git diff --check origin/master...HEAD
```

Expected: both shell tests pass, both skills validate, and syntax/diff checks exit `0`.

- [ ] **Step 2: Install the branch version for Codex**

Run from the repository root:

```bash
AI_GH_INSTALL_SKILLS=codex ./install.sh
```

Expected: output lists `~/.local/bin/gh`, `~/.local/bin/ai-gh-init`, and `~/.codex/skills/github-account-router/SKILL.md` as installed.

- [ ] **Step 3: Verify the installed sandbox failure**

Run through normal sandboxed execution:

```bash
gh pr list --repo LukeJiaoR/ai-gh-account-router
```

Expected: exit `77`; stderr begins with `GH_EXTERNAL_EXECUTION_REQUIRED`; no GitHub request is attempted.

- [ ] **Step 4: Verify local-only commands still work**

Run through normal sandboxed execution:

```bash
gh --version
gh ai-account
```

Expected: both exit `0`; `gh ai-account` reports the current repository and its local tag.

- [ ] **Step 5: Verify external execution succeeds**

Run the same PR list command directly with `sandbox_permissions: "require_escalated"` and a scoped justification.

Expected: exit `0` and normal GitHub output, proving external execution does not retain `CODEX_SANDBOX=seatbelt`.

- [ ] **Step 6: Review, push, and open the PR**

Before the GitHub write, verify routed identity and target:

```bash
gh api user --jq .login
gh api repos/LukeJiaoR/ai-gh-account-router --jq .full_name
```

Expected: `LukeJiaoR` and `LukeJiaoR/ai-gh-account-router` through approved external execution.

Then push `codex/gh-sandbox-fast-fail` using the `github-luke` SSH host and create a PR targeting `master`. Include the repository verification suite and real installed-wrapper checks in the PR body.
