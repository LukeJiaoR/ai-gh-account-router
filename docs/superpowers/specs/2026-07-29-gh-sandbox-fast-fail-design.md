# GitHub CLI Sandbox Fast-Fail Design

## Context

Codex can discover the GitHub Account Router skill without loading it when a task starts as local Git work and only later performs incidental `gh` checks. In that case, the wrapper currently proceeds inside the macOS seatbelt sandbox. Network or Keychain access may then fail before the agent retries with external execution.

The wrapper cannot elevate itself or request Codex approval. It can only detect the restricted environment, fail predictably, and tell the caller how to retry.

Observed environment behavior:

- Sandboxed execution sets `CODEX_SANDBOX=seatbelt`.
- Approved external execution does not set `CODEX_SANDBOX`.
- `CODEX_SANDBOX_NETWORK_DISABLED=1` is present in both environments and is not a valid discriminator.

## Goals

- Fail before credential or network access when a non-local `gh` command runs inside Codex seatbelt.
- Emit a stable machine-readable marker and a concise human-readable retry instruction.
- Preserve useful local-only wrapper and CLI commands in the sandbox.
- Ensure `GH_AI_BYPASS=1` cannot bypass the sandbox guard.
- Keep behavior unchanged outside Codex seatbelt and in other agent runtimes.

## Non-Goals

- The wrapper will not attempt privilege escalation or invoke Codex approval APIs.
- The wrapper will not govern `git` commands or `.git` metadata writes.
- The wrapper will not probe GitHub, DNS, or Keychain access to infer sandbox state.

## Approaches Considered

### Environment guard (selected)

Check for the exact observed value `CODEX_SANDBOX=seatbelt` before any credential lookup or real `gh` execution. This is deterministic, fast, and has no network side effects. External execution clears the variable, preventing retry loops.

### Capability probes

Probe Keychain or GitHub before each command. This adds latency, can prompt unexpectedly, conflates outages with sandboxing, and may expose inconsistent errors. Rejected.

### Automatic re-execution

Have the wrapper request external execution itself. A child process cannot set Codex tool-call permissions or create an approval request, so this is not technically available. Rejected.

## Command Classification

The following commands remain available inside seatbelt because they require only local wrapper state or static CLI output:

- `gh ai-account`
- `gh ai-status`
- `gh` with no arguments
- `gh version`
- `gh --version`
- `gh help`
- `gh --help`
- `gh <command> --help`

All other invocations fail fast while `CODEX_SANDBOX=seatbelt`. A conservative default is intentional: commands that appear informational may still read authentication state, extensions, configuration, or the network.

## Error Contract

The wrapper writes these lines to stderr and exits with code `77` (`EX_NOPERM`):

```text
GH_EXTERNAL_EXECUTION_REQUIRED
gh wrapper: Codex seatbelt blocks authenticated GitHub access.
gh wrapper: retry this command with sandbox_permissions="require_escalated".
```

The wrapper does not echo the complete command or arguments because they may contain sensitive values. The stable first line is intended for agent and test detection.

## Execution Order

1. Resolve and validate the real `gh` path.
2. Parse the command and identify local-only invocations.
3. If `CODEX_SANDBOX=seatbelt` and the invocation is not local-only, emit the error contract and exit `77`.
4. Process `GH_AI_BYPASS` only after the guard.
5. Continue existing account-routing behavior.

This order ensures bypass remains diagnostic rather than an escape from sandbox policy.

## Testing

Add wrapper tests with a fake real `gh` binary that records whether it was invoked.

Required cases:

- A routed command under seatbelt exits `77`, emits the marker, and never invokes real `gh`.
- `gh auth status` under seatbelt fails identically before Keychain access.
- `GH_AI_BYPASS=1` under seatbelt still fails.
- Local-only commands under seatbelt keep working.
- The same routed command without `CODEX_SANDBOX` reaches real `gh` and preserves existing routing.
- `CODEX_SANDBOX_NETWORK_DISABLED=1` without `CODEX_SANDBOX=seatbelt` does not trigger the guard.

Run existing layout, shell syntax, installation, and uninstall checks to prevent regression.

## Documentation And Release

Update README, the canonical skill, fallback agent instructions, and release notes. The guidance must explain that the marker requires retrying the exact operation through approved external execution and that this mechanism does not cover `git worktree`, branch deletion, or other Git metadata writes.
