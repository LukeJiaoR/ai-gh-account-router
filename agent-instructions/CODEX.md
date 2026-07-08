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

Run:

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
gh pr merge 123
gh api user --jq .login
```

## Do not route global setup

These commands intentionally bypass account routing:

```bash
gh auth ...
gh config ...
gh repo ...
```

Do not use them to switch active accounts during repo work.
