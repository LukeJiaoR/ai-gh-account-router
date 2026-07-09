# ai-gh-account-router

> **Make `gh` safe for AI agents on machines with multiple GitHub accounts.**

`ai-gh-account-router` is a tiny local wrapper around GitHub CLI. It lets each local repository declare which logged-in GitHub account should be used for repo-scoped `gh` commands, while leaving global GitHub CLI commands untouched.

It is designed for AI/Codex/Claude/Cursor/OpenClaw/AGY-style agents that operate real repositories and should not accidentally use the wrong GitHub identity.

---

## The problem

GitHub CLI can keep multiple accounts logged in for the same host, but normal `gh` behavior still depends on a current active/default account. That is fine for a human, but risky for an agent:

- one machine may have personal, work, client, and bot GitHub accounts
- repo owners may not match the account that should operate the repo
- agents often run `gh pr`, `gh issue`, and `gh api` without knowing your active account
- switching accounts globally with `gh auth switch` is easy to forget and unsafe for automation

This tool solves that with a local-only per-repo tag:

```text
.ai-gh-account
```

Example:

```text
LukeJiaoR
```

The tag file is ignored through `.git/info/exclude`, so it does not pollute the repository and never gets committed.

---

## How it works

After installation, your shell resolves `gh` to:

```text
~/.local/bin/gh
```

That wrapper reads the current repository's `.ai-gh-account` file only for a narrow allowlist of repo-oriented commands.

If the tag exists, it fetches that account's token from the real GitHub CLI:

```bash
gh auth token --user <account>
```

Then it executes the real `gh` with `GH_TOKEN` set only for that command.

If the tag is missing, or the command is global/non-routed, it falls back to normal `gh` behavior.

---

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
gh repo sync ...
```

These are the commands agents commonly use to manage PRs, issues, Actions, releases, and repo-level metadata.

`gh repo sync` is the only routed `gh repo` subcommand. Other `gh repo ...` commands still bypass routing because they are usually global/bootstrap operations.

---

## Non-routed commands

Everything else goes directly to the original GitHub CLI, including:

```bash
gh auth ...
gh config ...
gh repo clone ...
gh repo create ...
gh repo fork ...
gh repo view ...
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

This is intentional. Commands like `gh auth`, `gh config`, `gh repo clone`, `gh repo create`, and `gh repo fork` are global/bootstrap operations and should not inherit the current repo's account tag.

---

## `git pull` and `gh repo sync`

This tool does not route `git pull`, because `git` uses Git's own authentication path rather than GitHub CLI's `GH_TOKEN` path.

For agent workflows that need a GitHub CLI-native sync command, use:

```bash
gh repo sync
```

Useful examples:

```bash
# Sync the current local repository from its remote parent/default source
gh repo sync

# Sync a specific branch
gh repo sync --branch dev

# Sync from an explicit source repository
gh repo sync --source owner/repo --branch main
```

Important difference: `gh repo sync` is not a full replacement for `git pull`. It syncs a destination repository/branch from a source repository/branch. It is useful for simple fast-forward-style repository syncs, but normal Git workflows with local merge/rebase behavior should still use `git pull` or `git fetch`.

---

## Install

```bash
git clone https://github.com/LukeJiaoR/ai-gh-account-router.git
cd ai-gh-account-router
./install.sh
```

The wrapper and `ai-gh-init` are always installed to:

```text
~/.local/bin/gh
~/.local/bin/ai-gh-init
```

The agent skill install is interactive. The installer shows known agent skill roots and asks where to install `SKILL.md`.

Missing agent directories are **not** created unless you explicitly choose them.

Interactive options:

```text
1) Install to existing agent roots only
2) Choose agents manually (creates selected missing roots)
3) Skip skill install
4) Install to all known roots (creates missing roots)
```

Known local skill roots:

```text
~/.agent-skills/github-ai-account/SKILL.md
~/.codex/skills/github-ai-account/SKILL.md
~/.claude/skills/github-ai-account/SKILL.md
~/.agy/skills/github-ai-account/SKILL.md
```

Restart your shell or run:

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

The original GitHub CLI path is stored at:

```text
~/.config/ai-gh/real-gh-path
```

---

## Non-interactive install

For bootstrap scripts or CI-like setup, control skill installation with `AI_GH_INSTALL_SKILLS`:

```bash
AI_GH_INSTALL_SKILLS=none ./install.sh
AI_GH_INSTALL_SKILLS=existing ./install.sh
AI_GH_INSTALL_SKILLS=all ./install.sh
AI_GH_INSTALL_SKILLS=codex,claude,agy ./install.sh
```

Modes:

```text
none      skip skill install
existing  install only to existing known skill roots; do not create missing roots
all       install to all known roots; create missing roots
list      comma-separated ids: generic,codex,claude,agy
```

When stdin is not interactive and `AI_GH_INSTALL_SKILLS` is unset, the installer uses `existing` mode.

If an agent uses a different skill directory, copy `agent-instructions/SKILL.md` there manually.

---

## Per-repository setup

Inside a repository:

```bash
ai-gh-init
```

You will be asked to choose from currently logged-in GitHub CLI accounts.

You can also set it directly:

```bash
ai-gh-init LukeJiaoR
ai-gh-init ranjugao
ai-gh-init your-bot-account
```

Inspect the current repo tag:

```bash
gh ai-account
```

Test routed identity:

```bash
gh api user --jq .login
```

---

## Agent usage

Once installed, agents do **not** need a special command.

They should simply use normal `gh` commands:

```bash
gh pr list
gh issue list
gh pr view 123
gh pr merge 123
gh repo sync --branch dev
```

If the repo has `.ai-gh-account`, the wrapper selects the tagged account. If not, `gh` behaves normally.

---

## Portable agent instructions

This repo includes portable agent instructions under:

```text
agent-instructions/
```

Templates:

```text
agent-instructions/SKILL.md     # portable SKILL.md-style instruction
agent-instructions/CODEX.md     # Codex-oriented copy
agent-instructions/CLAUDE.md    # Claude-oriented copy
agent-instructions/CURSOR.md    # Cursor-oriented copy
agent-instructions/OPENCLAW.md  # OpenClaw-style copy
agent-instructions/AGENTS.md    # generic repo-agent copy
```

The important rule is the same for every agent:

> Use `gh` normally. Do not use `gh auth switch`. Do not infer account from repo owner. Let the local wrapper route repo-scoped commands.

Many modern agent systems use a folder with a `SKILL.md` file as a portable instruction bundle; this repository keeps the instruction text narrow, explicit, and local-environment-focused so it can be copied into Codex, Claude, OpenClaw, Cursor rules, AGY skills, or a repo-level `AGENTS.md` without changing the wrapper itself.

---

## Bypass

Temporarily bypass the wrapper:

```bash
GH_AI_BYPASS=1 gh auth status
```

---

## Uninstall

```bash
./uninstall.sh
hash -r
```

This removes:

```text
~/.local/bin/gh
~/.local/bin/ai-gh-init
~/.agent-skills/github-ai-account/SKILL.md
~/.codex/skills/github-ai-account/SKILL.md
~/.claude/skills/github-ai-account/SKILL.md
~/.agy/skills/github-ai-account/SKILL.md
```

It does not delete your original GitHub CLI.

---

## Security model

This tool intentionally has a small surface area:

- no tokens are written to repositories
- `.ai-gh-account` contains only an account name
- `.ai-gh-account` is ignored through `.git/info/exclude`
- the wrapper uses a narrow allowlist of routed commands
- global/bootstrap commands fall back to real `gh`
- invalid or empty account tags fail closed
- agents do not need to know or handle raw tokens
- missing agent skill directories are not created unless the user explicitly chooses them

---

## What this does not solve

This controls GitHub CLI authentication for `gh` commands.

It does **not** fully control:

```bash
git push
git fetch
git pull
```

Those use Git's own authentication path. For multi-account Git operations, prefer repo-specific SSH aliases or explicit Git credential configuration.

---

## License

MIT
