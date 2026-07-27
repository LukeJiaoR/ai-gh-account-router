---
name: github-account-router
description: Use when running GitHub CLI (`gh`) commands on a machine with multiple logged-in GitHub accounts, or when authenticated `gh` access needs host network or credential access outside an agent sandbox.
---

# GitHub Account Router

Use normal `gh` commands so repository-scoped account routing and authenticated host access work together. Execution approval grants capability, not authority for a GitHub-side write.

## Core rules

- Use the `gh` resolved from `PATH`; do not replace or bypass the wrapper.
- Never run `gh auth switch`, infer the login from the repository owner, or put tokens in the repository.
- Never expose tokens, credential files, Keychain contents, or secret-bearing output.

## Sandboxed runtimes

When the runtime restricts network or credential-store access:

1. Run `gh auth status` through its approved host/external execution mechanism before GitHub work.
2. Run each authenticated `gh` command directly through that mechanism with a concise approval reason naming the operation and relevant resource.
3. Keep reusable approvals narrow, such as the `gh pr view` command family. Never request blanket approval for all `gh` commands.
4. Do not hide `gh` inside a shell wrapper, script, pipeline, or command substitution when direct execution is available.

For Codex-style tools, use a direct command with `sandbox_permissions: "require_escalated"`, a scoped `justification`, and an optional narrow `prefix_rule`.

If host execution cannot access GitHub or the credential store, stop and report the failure. Do not fall back to sandboxed or unauthenticated execution.

## Repository account tag

The wrapper reads `.ai-gh-account` from the Git repository root. The file contains exactly one GitHub login and must remain local through `.git/info/exclude`; never commit it.

If the file is missing and a specific identity is required, ask the user which logged-in account to use, then run `ai-gh-init <account>`. Use interactive `ai-gh-init` only when no account was provided. Empty, invalid, or logged-out tags must fail closed; do not bypass them.

| Routed with `.ai-gh-account` | Global/bootstrap, not routed |
| --- | --- |
| `gh pr`, `issue`, `run`, `workflow` | `gh auth`, `config`, `search` |
| `gh release`, `project`, `api` | `gh repo clone`, `create`, `fork`, `view` |
| `gh secret`, `variable`, `label` | `gh extension`, `alias`, `gist`, `org`, `codespace` |
| `gh repo sync` | Other `gh repo` subcommands |

Outside a Git repository or without a tag, routed commands fall back to normal `gh` behavior.

## Identity and write safety

- Before a GitHub write, verify the routed target with `gh api repos/OWNER/REPO --jq '.full_name'` and compare `gh api user --jq '.login'` with `.ai-gh-account`, using approved host execution when required. Do not use non-routed `gh repo view` for an authentication-sensitive check.
- Network, Keychain, or sandbox approval does not authorize creating, merging, closing, deleting, or modifying GitHub resources. Those actions require explicit user direction.
- Do not run `gh auth login` merely because sandboxed authentication fails. Diagnose host credential access first; authenticate only when the user asks.

## Diagnostics

```bash
gh ai-account
gh api user --jq .login
GH_AI_BYPASS=1 gh auth status
```

Use bypass only for diagnostics. This router controls `gh`, not `git push`, `git fetch`, or `git pull`; Git uses its own SSH or credential configuration.
