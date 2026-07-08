#!/usr/bin/env bash
set -euo pipefail

rm -f "$HOME/.local/bin/gh" "$HOME/.local/bin/ai-gh-init"

echo "Removed:"
echo "  $HOME/.local/bin/gh"
echo "  $HOME/.local/bin/ai-gh-init"
echo
echo "Kept config:"
echo "  $HOME/.config/ai-gh/real-gh-path"
echo
echo "If needed, remove manually:"
echo "  rm -rf ~/.config/ai-gh"
echo
echo "Run:"
echo "  hash -r"
