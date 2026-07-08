# AGENTS.md snippet: GitHub account routing

Copy this into a repository's `AGENTS.md` only when you want project-level agents to know about local GitHub account routing.

## GitHub CLI account routing

This machine may use `ai-gh-account-router`, a local wrapper for GitHub CLI.

Agents should use normal `gh` commands:

```bash
gh pr list
gh issue list
gh pr view 123
gh pr merge 123
```

Do not use `gh auth switch`.

Do not infer the GitHub account from the repo owner.

Do not commit `.ai-gh-account`.

Do not write tokens into repository files.

When identity matters, check:

```bash
gh ai-account
gh api user --jq .login
```

If `.ai-gh-account` is missing and GitHub operations require a specific account, ask the user which logged-in account should be used, then run:

```bash
ai-gh-init
```

The account tag is local-only and should be ignored through `.git/info/exclude`.
