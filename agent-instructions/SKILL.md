---
name: GitHub Account Router
description: Use when operating GitHub repositories with `gh` on a machine that may have multiple logged-in GitHub accounts. This skill tells agents to use normal `gh` commands while relying on the local ai-gh-account-router wrapper for repo-scoped account routing.
---

# GitHub Account Router

Use this skill when working with GitHub repositories through GitHub CLI on this machine.

## Core rule

Use `gh` normally.

Do **not** use `gh auth switch`.

Do **not** write tokens into the repository.

Do **not** infer the GitHub account from repo owner.

Repo owner may not equal the GitHub login account.

## Local account tag

Each repository that needs deterministic AI account routing may have this local-only file at the repository root:

```text
.ai-gh-account
```

The file contains exactly one GitHub account name.

Examples:

```text
LukeJiaoR
```

```text
ranjugao
```

```text
your-bot-account
```

The file must be ignored locally through:

```text
.git/info/exclude
```

Do not commit `.ai-gh-account`.

## Initialization

If `.ai-gh-account` is missing and GitHub operations need a specific account, ask the user which logged-in GitHub account should operate this repository, then run:

```bash
ai-gh-init
```

The command lists currently logged-in GitHub CLI accounts and asks the user to choose one.

If the user already provided the account name, explicit initialization is allowed:

```bash
ai-gh-init <github-account-name>
```

## Routed commands

These commands use `.ai-gh-account` when the file exists:

```bash
gh pr ...
gh issue ...
gh run ...
gh workflow ...
gh release ...
gh project ...
gh api ...
gh secret ...
gh variable ...
gh label ...
```

If `.ai-gh-account` is missing, these commands fall back to normal GitHub CLI behavior.

If `.ai-gh-account` exists but is empty or points to an account that is not logged in, the wrapper fails closed.

## Non-routed commands

All other commands go directly to the original GitHub CLI, including but not limited to:

```bash
gh auth ...
gh config ...
gh repo ...
gh extension ...
gh alias ...
gh gist ...
gh org ...
gh codespace ...
gh search ...
gh ssh-key ...
gh gpg-key ...
gh help
gh version
```

This is intentional. Commands like `gh auth`, `gh config`, `gh repo clone`, `gh repo create`, and `gh repo fork` are global or bootstrap operations and should not inherit the current repo's account tag.

## Diagnostics

Check the current repo's AI GitHub account tag:

```bash
gh ai-account
```

Test the routed identity:

```bash
gh api user --jq .login
```

Bypass the wrapper temporarily:

```bash
GH_AI_BYPASS=1 gh auth status
```

## Git note

This only controls GitHub CLI commands.

It does not fully control:

```bash
git push
git fetch
git pull
```

Those use Git's own authentication path. For multiple GitHub accounts, prefer repo-specific SSH aliases or explicit Git credential configuration.
