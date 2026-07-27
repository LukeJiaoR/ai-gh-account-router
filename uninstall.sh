#!/usr/bin/env bash
set -euo pipefail

rm -f "$HOME/.local/bin/gh" "$HOME/.local/bin/ai-gh-init"
skill_roots=("$HOME/.agent-skills" "$HOME/.codex/skills" "$HOME/.claude/skills" "$HOME/.agy/skills")

for root in "${skill_roots[@]}"; do
  rm -f "$root/github-account-router/SKILL.md"
  rm -f "$root/github-ai-account/SKILL.md"
  rmdir "$root/github-account-router" 2>/dev/null || true
  rmdir "$root/github-ai-account" 2>/dev/null || true
done

echo "Removed:"
echo "  $HOME/.local/bin/gh"
echo "  $HOME/.local/bin/ai-gh-init"
for root in "${skill_roots[@]}"; do
  echo "  $root/github-account-router/SKILL.md"
  echo "  $root/github-ai-account/SKILL.md (legacy)"
done
echo
echo "Kept config:"
echo "  $HOME/.config/ai-gh/real-gh-path"
echo
echo "If needed, remove manually:"
echo "  rm -rf ~/.config/ai-gh"
echo
echo "Run:"
echo "  hash -r"
