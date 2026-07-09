# Release Notes

## 0.4.0

Installer safety refresh.

- `install.sh` now asks where to install agent skills in interactive shells.
- Missing agent skill directories are no longer created by default.
- Non-interactive installs default to `AI_GH_INSTALL_SKILLS=existing` behavior.
- Added `AI_GH_INSTALL_SKILLS` modes: `none`, `existing`, `all`, and comma-separated ids such as `codex,claude,agy`.
- README now documents interactive and non-interactive skill installation behavior.

## 0.3.0

Installer refresh for local agent skill discovery.

- `install.sh` now copies portable `SKILL.md` into common local agent discovery paths.
- Added generic `~/.agent-skills/github-ai-account/SKILL.md` install target.
- Added Codex, Claude, and AGY local skill install targets.
- `uninstall.sh` now removes the installed skill copies.
- README now documents installed skill locations and AGY usage.

## 0.2.0

Documentation and agent-instruction refresh.

- Polished README for public/reusable tool use.
- Added portable `agent-instructions/SKILL.md`.
- Added agent-specific copies for Codex, Claude, Cursor, OpenClaw-style agents, and generic `AGENTS.md` usage.
- Updated bundled skill under `skills/github-ai-account/SKILL.md` to be platform-neutral.
- Clarified that agents should use normal `gh` commands and let the local wrapper handle account routing.

## 0.1.0

Initial version.

- Local `gh` wrapper for narrow repo-scoped command routing.
- Per-repo `.ai-gh-account` tag.
- `ai-gh-init` account selection helper.
- Local Codex skill documentation.
- Bypass via `GH_AI_BYPASS=1`.
