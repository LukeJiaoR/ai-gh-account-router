# Codex instructions: GitHub account routing

Use these instructions when Codex operates repositories on a machine with `ai-gh-account-router` installed.

## Rules

- Use normal `gh` commands.
- Do not use `gh auth switch`.
- Do not write GitHub tokens into files.
- Do not infer the operating account from repo owner.
- Repo owner may not equal the GitHub login account.

## Expected local behavior

The user's `gh` command may be a local wrapper at:

```text
~/.local/bin/gh
```

For repo-scoped commands, it reads:

```text
.ai-gh-account
```

from the current repository root.

The file contains the GitHub account name to use for that repo.

## Before GitHub work

Run `gh auth status` directly with `sandbox_permissions: "require_escalated"` so host network and Keychain credentials are available. Run each authenticated `gh` command the same way, with a scoped `justification` and optional narrow `prefix_rule`. Do not wrap `gh` in a shell, script, or pipeline.

If the wrapper exits `77` with `GH_EXTERNAL_EXECUTION_REQUIRED`, retry the same `gh` operation through approved external execution. Do not bypass the guard. It does not cover `git` commands or Git metadata writes.

Then check:

```bash
gh ai-account
```

If the tag is missing and the task requires a specific GitHub identity, ask the user which logged-in account should operate the repository, or run:

```bash
ai-gh-init
```

when interactive setup is acceptable.

## Use normally

```bash
gh pr list
gh issue list
gh pr view 123
gh pr checks 123
gh api user --jq .login
```

Execution approval through the sandbox grants capability, not authority for GitHub writes. Before an explicitly requested mutation, compare `gh api user --jq .login` with `.ai-gh-account` and verify the routed target with `gh api repos/OWNER/REPO --jq .full_name`. Stop if host authentication or either check fails.

## Do not route global setup

These commands intentionally bypass account routing:

```bash
gh auth ...
gh config ...
gh repo clone ...
gh repo create ...
gh repo fork ...
gh repo view ...
```

`gh repo sync` is the only routed `gh repo` subcommand. Do not use global commands to switch active accounts during repo work.
