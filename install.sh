#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin" "$HOME/.config/ai-gh"

find_real_gh() {
  if [ -f "$HOME/.config/ai-gh/real-gh-path" ]; then
    local saved
    saved="$(cat "$HOME/.config/ai-gh/real-gh-path")"

    if [ -x "$saved" ] && [ "$saved" != "$HOME/.local/bin/gh" ]; then
      printf "%s\n" "$saved"
      return 0
    fi
  fi

  local candidates
  candidates="$(
    {
      type -a -P gh 2>/dev/null || true
      printf "%s\n" /opt/homebrew/bin/gh /usr/local/bin/gh /usr/bin/gh
    } | awk '!seen[$0]++'
  )"

  while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue

    case "$candidate" in
      "$HOME/.local/bin/gh")
        continue
        ;;
    esac

    if [ -x "$candidate" ]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done <<< "$candidates"

  return 1
}

real_gh="$(find_real_gh || true)"

if [ -z "$real_gh" ]; then
  echo "Cannot find real gh binary. Install GitHub CLI first." >&2
  exit 1
fi

printf "%s\n" "$real_gh" > "$HOME/.config/ai-gh/real-gh-path"

install -m 0755 bin/gh "$HOME/.local/bin/gh"
install -m 0755 bin/ai-gh-init "$HOME/.local/bin/ai-gh-init"

if ! printf "%s" "$PATH" | grep -q "$HOME/.local/bin"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  echo "Added ~/.local/bin to ~/.zshrc"
fi

echo
echo "Installed ai-gh-account-router."
echo "Real gh:  $real_gh"
echo "Wrapper:  $HOME/.local/bin/gh"
echo "Init:     $HOME/.local/bin/ai-gh-init"
echo
echo "Run:"
echo '  source ~/.zshrc'
echo '  hash -r'
echo '  which gh'
echo '  type -a gh'
echo
echo "Per repo:"
echo '  cd /path/to/repo'
echo '  ai-gh-init'
echo '  gh ai-account'
