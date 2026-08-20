# ai-gh-account-router

[English](README.md) | [简体中文](README.zh-CN.md)

A small local wrapper that makes GitHub CLI safer on machines with multiple GitHub accounts.

Each repository can select the account used by repository-scoped `gh` commands without changing GitHub CLI's global active account. The selection stays local and is never committed.

## Why use it?

GitHub CLI can store several accounts for the same host, but commands normally use one active account. This is easy to miss in automated or agent-driven workflows and can cause a command to run under the wrong identity.

This wrapper adds a repository-local account tag:

```text
.ai-gh-account
```

The file contains only a GitHub login, for example:

```text
work-account
```

`ai-gh-init` adds the file to `.git/info/exclude`, so the selection remains local to the current clone.

## How it works

After installation, the shell resolves `gh` to the wrapper in `~/.local/bin`. For supported repository-scoped commands, the wrapper:

1. Finds the current repository's `.ai-gh-account` file.
2. Requests that account's token from the original GitHub CLI.
3. Sets `GH_TOKEN` only for the current command.
4. Runs the original `gh` executable.

If there is no tag, or the command is not routed, normal GitHub CLI behavior is preserved. Empty or invalid tags fail closed.

## Command routing

The following commands use the repository tag when it exists:

```text
gh pr          gh issue       gh run          gh workflow
gh release     gh project     gh api          gh secret
gh variable    gh label       gh repo sync
```

Global and bootstrap commands are not routed, including:

```text
gh auth        gh config      gh repo clone   gh repo create
gh repo fork   gh repo view   gh extension    gh alias
gh gist        gh org         gh codespace    gh search
```

Only `gh repo sync` is routed within the `gh repo` command group.

## Requirements

- Git
- GitHub CLI (`gh`)
- Bash
- One or more GitHub accounts already authenticated with GitHub CLI

## Install

```bash
git clone <repository-url>
cd ai-gh-account-router
./install.sh
```

The installer places the wrapper and setup command at:

```text
~/.local/bin/gh
~/.local/bin/ai-gh-init
```

Restart the shell, or reload its configuration and command cache:

```bash
source ~/.zshrc
hash -r
```

Verify that the wrapper is first on `PATH`:

```bash
which gh
type -a gh
```

The original GitHub CLI path is recorded in `~/.config/ai-gh/real-gh-path`.

### Agent instructions

The interactive installer can install the bundled `SKILL.md` into existing supported agent directories, selected directories, all known directories, or none.

For non-interactive installation, set `AI_GH_INSTALL_SKILLS`:

```bash
AI_GH_INSTALL_SKILLS=none ./install.sh
AI_GH_INSTALL_SKILLS=existing ./install.sh
AI_GH_INSTALL_SKILLS=all ./install.sh
AI_GH_INSTALL_SKILLS=codex,claude,agy ./install.sh
```

When stdin is not interactive and the variable is unset, `existing` mode is used. Missing agent directories are created only when explicitly selected.

Portable instruction templates are available in `agent-instructions/` for tools that cannot discover skills automatically.

## Configure a repository

Run this inside a Git repository:

```bash
ai-gh-init
```

Choose one of the accounts already logged in to GitHub CLI. For scripts, an account can be supplied directly:

```bash
ai-gh-init work-account
```

Inspect the local tag and confirm the routed identity:

```bash
gh ai-account
gh api user --jq .login
```

Agents and scripts can then use normal commands:

```bash
gh pr list
gh issue list
gh pr view 123
gh pr checks 123
```

Do not use `gh auth switch` in routed workflows, and do not infer the required account from the repository owner.

## Sandboxed agent runtimes

In a restricted Codex seatbelt, authenticated commands stop before the original `gh` runs and print:

```text
GH_EXTERNAL_EXECUTION_REQUIRED
```

The wrapper exits with status `77`. Retry the same command through the runtime's approved external execution mechanism. Local help, version, and router diagnostic commands remain available.

External execution approval only grants access to the credential store or network. It does not authorize GitHub-side changes; agents must still obtain explicit authorization before creating or modifying remote resources.

## Repository sync

The router does not affect `git pull`, `git fetch`, or `git push`, because Git uses its own authentication path.

For a GitHub CLI-native sync operation, use:

```bash
gh repo sync
gh repo sync --branch main
gh repo sync --source upstream-owner/upstream-repo --branch main
```

`gh repo sync` is not a full replacement for `git pull`; local merge and rebase workflows should continue to use Git directly.

## Security model

- Tokens are never written to the repository.
- The local tag contains only an account login.
- The tag is excluded through `.git/info/exclude`.
- Only a narrow allowlist of commands is routed.
- `GH_TOKEN` is scoped to one command invocation.
- Invalid and empty account tags fail closed.
- Global GitHub CLI commands keep their normal behavior.
- Agent skill directories are not created without explicit selection.

The tool routes GitHub CLI authentication only. Configure SSH aliases or Git credential helpers separately for multi-account Git operations.

## Bypass

To run the original GitHub CLI without routing for one command:

```bash
GH_AI_BYPASS=1 gh auth status
```

## Uninstall

```bash
./uninstall.sh
hash -r
```

The uninstaller removes the wrapper, `ai-gh-init`, and installed copies of the bundled agent skill. It does not remove the original GitHub CLI or sign out any account.

## License

[MIT](LICENSE)
