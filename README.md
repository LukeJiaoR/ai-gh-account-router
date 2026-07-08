# ai-gh-account-router

A small local wrapper for GitHub CLI (`gh`) that routes repository-scoped GitHub operations through the correct logged-in GitHub account.

It is designed for AI/Codex workflows on machines where multiple GitHub accounts are logged in through `gh auth login`.

## Problem

GitHub CLI supports multiple logged-in accounts for the same host, but it still has an active account. When AI agents operate multiple repositories, relying on the active account can accidentally use the wrong GitHub identity.

This tool lets each local repository declare its intended GitHub account using a local-only tag file:

```text
.ai-gh-account
```

The tag file is ignored through:

```text
.git/info/exclude
```

No token is written to the repository.

## Behavior

After installation, `gh` itself becomes a narrow wrapper.

If the current repository has `.ai-gh-account`, selected repo-oriented commands use that account's token:

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

If `.ai-gh-account` is missing, the wrapper falls back to normal `gh` behavior.

All other commands always go directly to the original GitHub CLI:

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

This is intentional. Commands like `gh auth`, `gh config`, `gh repo clone`, `gh repo create`, and `gh repo fork` are global or bootstrap operations and should not inherit the current repository's account tag.

## Install

```bash
./install.sh
```

Then restart your shell or run:

```bash
source ~/.zshrc
hash -r
```

Verify:

```bash
which gh
type -a gh
```

Expected first result:

```text
/Users/you/.local/bin/gh
```

## Per-repository setup

Inside a repository:

```bash
ai-gh-init
```

This lists currently logged-in GitHub CLI accounts and lets you choose one.

Or set it explicitly:

```bash
ai-gh-init LukeJiaoR
ai-gh-init ranjugao
ai-gh-init lukejiaosh-svg
```

Inspect the current repository tag:

```bash
gh ai-account
```

Test the routed identity:

```bash
gh api user --jq .login
```

## Bypass

Temporarily bypass the wrapper:

```bash
GH_AI_BYPASS=1 gh auth status
```

## Uninstall

```bash
./uninstall.sh
```

## Notes

This only controls GitHub CLI commands.

It does not fully control:

```bash
git push
git fetch
git pull
```

Those use Git's own authentication path. For multiple GitHub accounts, prefer repo-specific SSH aliases or explicit Git credential configuration.

## AI / Codex usage

AI agents can simply use normal `gh` commands.

They do not need to know account-routing details. The wrapper handles account selection when `.ai-gh-account` exists.

A Codex skill is included in:

```text
skills/github-ai-account/SKILL.md
```
