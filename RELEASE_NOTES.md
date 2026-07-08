# Release Notes

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
