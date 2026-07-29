# AGENTS.md snippet: GitHub account routing

Copy this into a repository's `AGENTS.md` only when you want project-level agents to know about local GitHub account routing.

## GitHub CLI account routing

This machine may use `ai-gh-account-router`, a local wrapper for GitHub CLI.

Agents should use normal `gh` commands:

```bash
gh pr list
gh issue list
gh pr view 123
gh pr checks 123
```

Do not use `gh auth switch`.

Do not infer the GitHub account from the repo owner.

Do not commit `.ai-gh-account`.

Do not write tokens into repository files.

When the agent runtime restricts network or credential access, run `gh auth status` and each authenticated `gh` command directly through its approved host/external execution mechanism. Keep approvals narrow and do not hide `gh` in a shell wrapper or pipeline.

If the wrapper exits `77` with `GH_EXTERNAL_EXECUTION_REQUIRED`, retry the same `gh` operation through approved external execution. Do not bypass the guard. It does not cover `git` commands or Git metadata writes.

Execution approval does not authorize GitHub writes. Before an explicitly requested mutation, compare `gh api user --jq .login` with `.ai-gh-account` and verify the target with `gh api repos/OWNER/REPO --jq .full_name`. Stop if host authentication or either check fails.

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
