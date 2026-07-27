# Cursor instructions: GitHub account routing

Use these rules when Cursor Agent works in a repository on a machine with `ai-gh-account-router` installed.

## Default behavior

Use normal `gh` commands.

```bash
gh pr list
gh issue list
gh pr view 123
gh pr checks 123
```

The local `gh` wrapper chooses the correct GitHub account for repo-scoped commands when `.ai-gh-account` exists at the repository root.

## Never do this

```bash
gh auth switch
```

Do not change global GitHub CLI account state during repository work.

Do not infer account identity from the repository owner.

Do not commit `.ai-gh-account`.

Do not store tokens in project files.

When the runtime restricts network or credential access, run `gh auth status` and authenticated `gh` commands directly through its approved host/external execution mechanism. Keep approvals narrow; execution approval never authorizes a GitHub write.

## Setup

Check the repo's configured account:

```bash
gh ai-account
```

If missing, ask the user which logged-in account should operate this repo, then run:

```bash
ai-gh-init
```

or:

```bash
ai-gh-init <github-account-name>
```

## Identity check

```bash
gh api user --jq .login
```

This should print the account from `.ai-gh-account` when the repo is tagged.

Before an explicitly requested mutation, compare the login with `.ai-gh-account` and verify the routed target with `gh api repos/OWNER/REPO --jq .full_name`. Stop if host authentication or either check fails.
