# Claude instructions: GitHub account routing

Use these instructions when Claude or Claude Code is asked to operate a local GitHub repository on a machine with multiple `gh` accounts.

## What to do

Use normal GitHub CLI commands:

```bash
gh pr list
gh issue list
gh pr view 123
gh pr merge 123
```

The local `gh` command may be wrapped by `ai-gh-account-router`. If the repository has `.ai-gh-account`, routed repo-scoped commands automatically use the tagged GitHub account.

## What not to do

Do not run:

```bash
gh auth switch
```

Do not infer account from the repo owner.

Do not write tokens to disk.

Do not commit `.ai-gh-account`.

## Setup check

Before repo operations, this is safe:

```bash
gh ai-account
```

If the tag is missing and account identity matters, ask the user which logged-in account to use, then run:

```bash
ai-gh-init
```

or, when the user has already specified the account:

```bash
ai-gh-init <github-account-name>
```

## Verification

To confirm routed identity:

```bash
gh api user --jq .login
```

To inspect normal GitHub CLI auth without routing:

```bash
GH_AI_BYPASS=1 gh auth status
```
