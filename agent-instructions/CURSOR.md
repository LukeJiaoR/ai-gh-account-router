# Cursor instructions: GitHub account routing

Use these rules when Cursor Agent works in a repository on a machine with `ai-gh-account-router` installed.

## Default behavior

Use normal `gh` commands.

```bash
gh pr list
gh issue list
gh pr view 123
gh pr merge 123
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
