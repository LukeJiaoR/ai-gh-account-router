# OpenClaw-style instructions: GitHub account routing

Use these instructions for local agents that discover tool-use rules from `SKILL.md`-style files.

## Capability

This repository provides deterministic GitHub CLI account routing for machines with multiple logged-in `gh` accounts.

The agent should use normal `gh` commands. The local wrapper handles account selection for repo-scoped operations.

## Activation cues

Use this instruction when the task involves:

- GitHub pull requests
- GitHub issues
- GitHub Actions runs or workflows
- GitHub releases
- GitHub API calls through `gh api`
- repository secrets, variables, labels, or project metadata

## Required behavior

Use:

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

Do not use:

```bash
gh auth switch
```

Do not infer the account from repo owner.

Do not commit `.ai-gh-account`.

Do not write tokens to the repository.

## Setup and diagnosis

Check current tag:

```bash
gh ai-account
```

Initialize when needed:

```bash
ai-gh-init
```

Verify routed account:

```bash
gh api user --jq .login
```

Bypass wrapper for global auth inspection:

```bash
GH_AI_BYPASS=1 gh auth status
```
