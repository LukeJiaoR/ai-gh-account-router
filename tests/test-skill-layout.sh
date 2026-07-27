#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
portable_skill="$repo_root/agent-instructions/SKILL.md"
skill_name="$(sed -n 's/^name: //p' "$portable_skill" | head -n 1)"
bundled_skill="$repo_root/skills/$skill_name/SKILL.md"

if [ ! -f "$bundled_skill" ]; then
  echo "missing bundled skill matching frontmatter name: $bundled_skill" >&2
  exit 1
fi

cmp "$portable_skill" "$bundled_skill"

grep -q 'target_dir="$root/'"$skill_name"'"' "$repo_root/install.sh"
grep -q 'legacy_target_dir="$root/github-ai-account"' "$repo_root/install.sh"
grep -q 'github-account-router/SKILL.md' "$repo_root/uninstall.sh"
grep -q 'github-ai-account/SKILL.md' "$repo_root/uninstall.sh"

for template in AGENTS.md CLAUDE.md CODEX.md CURSOR.md OPENCLAW.md; do
  template_path="$repo_root/agent-instructions/$template"
  grep -qi 'execution approval' "$template_path"
  grep -q "gh api user --jq .login" "$template_path"
  grep -q "gh api repos/OWNER/REPO --jq .full_name" "$template_path"
done

echo "skill layout checks passed"
