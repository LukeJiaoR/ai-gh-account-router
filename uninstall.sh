#!/usr/bin/env bash
set -euo pipefail

rm -f "$HOME/.local/bin/gh" "$HOME/.local/bin/ai-gh-init"
rm -f "$HOME/.agent-skills/github-ai-account/SKILL.md"
rm -f "$HOME/.codex/skills/github-ai-account/SKILL.md"
rm -f "$HOME/.claude/skills/github-ai-account/SKILL.md"
rm -f "$HOME/.agy/skills/github-ai-account/SKILL.md"

rmdir "$HOME/.agent-skills/github-ai-account" 2>/dev/null || true
rmdir "$HOME/.codex/skills/github-ai-account" 2>/dev/null || true
rmdir "$HOME/.claude/skills/github-ai-account" 2>/dev/null || true
rmdir "$HOME/.agy/skills/github-ai-account" 2>/dev/null || true

echo "Removed:"
echo "  $HOME/.local/bin/gh"
echo "  $HOME/.local/bin/ai-gh-init"
echo "  $HOME/.agent-skills/github-ai-account/SKILL.md"
echo "  $HOME/.codex/skills/github-ai-account/SKILL.md"
echo "  $HOME/.claude/skills/github-ai-account/SKILL.md"
echo "  $HOME/.agy/skills/github-ai-account/SKILL.md"
echo
echo "Kept config:"
echo "  $HOME/.config/ai-gh/real-gh-path"
echo
echo "If needed, remove manually:"
echo "  rm -rf ~/.config/ai-gh"
echo
echo "Run:"
echo "  hash -r"
