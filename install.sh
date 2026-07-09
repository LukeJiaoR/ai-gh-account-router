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

skill_source="agent-instructions/SKILL.md"
installed_skill_dirs=""
skipped_skill_dirs=""

skill_candidates=(
  "generic|Generic agent skills|$HOME/.agent-skills"
  "codex|Codex|$HOME/.codex/skills"
  "claude|Claude|$HOME/.claude/skills"
  "agy|AGY|$HOME/.agy/skills"
)

skill_root_for_id() {
  local requested="$1"
  local item id label root

  for item in "${skill_candidates[@]}"; do
    IFS='|' read -r id label root <<< "$item"
    if [ "$id" = "$requested" ]; then
      printf "%s\n" "$root"
      return 0
    fi
  done

  return 1
}

skill_label_for_id() {
  local requested="$1"
  local item id label root

  for item in "${skill_candidates[@]}"; do
    IFS='|' read -r id label root <<< "$item"
    if [ "$id" = "$requested" ]; then
      printf "%s\n" "$label"
      return 0
    fi
  done

  return 1
}

append_installed_skill() {
  local path="$1"
  installed_skill_dirs="${installed_skill_dirs}
  ${path}"
}

install_skill_to_root() {
  local root="$1"
  local target_dir="$root/github-ai-account"

  mkdir -p "$target_dir"
  install -m 0644 "$skill_source" "$target_dir/SKILL.md"
  append_installed_skill "$target_dir/SKILL.md"
}

install_skill_id() {
  local id="$1"
  local root

  root="$(skill_root_for_id "$id" || true)"
  if [ -z "$root" ]; then
    echo "Unknown agent id: $id" >&2
    return 2
  fi

  install_skill_to_root "$root"
}

install_existing_skill_roots() {
  local item id label root count=0

  for item in "${skill_candidates[@]}"; do
    IFS='|' read -r id label root <<< "$item"
    if [ -d "$root" ]; then
      install_skill_to_root "$root"
      count=$((count + 1))
    else
      skipped_skill_dirs="${skipped_skill_dirs}
  ${label}: $root"
    fi
  done

  return 0
}

install_all_skill_roots() {
  local item id label root

  for item in "${skill_candidates[@]}"; do
    IFS='|' read -r id label root <<< "$item"
    install_skill_to_root "$root"
  done
}

install_selected_skill_roots() {
  local selection="$1"
  local token

  selection="${selection//,/ }"

  for token in $selection; do
    case "$token" in
      generic|codex|claude|agy)
        install_skill_id "$token"
        ;;
      *)
        echo "Unknown skill target '$token'. Expected one of: generic,codex,claude,agy" >&2
        return 2
        ;;
    esac
  done
}

prompt_skill_install() {
  local existing_count=0
  local item id label root status default_choice choice numbers number selected_ids=""

  echo
  echo "Agent skill install"
  echo "-------------------"
  echo "The wrapper itself is installed automatically."
  echo "The portable SKILL.md can also be installed for local agents."
  echo "Missing agent directories are not created unless you explicitly choose them."
  echo
  echo "Known agent skill roots:"

  number=1
  for item in "${skill_candidates[@]}"; do
    IFS='|' read -r id label root <<< "$item"
    if [ -d "$root" ]; then
      status="exists"
      existing_count=$((existing_count + 1))
    else
      status="missing"
    fi
    printf "  %d) %-20s %-8s %s\n" "$number" "$label" "[$status]" "$root"
    number=$((number + 1))
  done

  echo
  echo "Choose skill install mode:"
  echo "  1) Install to existing agent roots only"
  echo "  2) Choose agents manually (creates selected missing roots)"
  echo "  3) Skip skill install"
  echo "  4) Install to all known roots (creates missing roots)"

  if [ "$existing_count" -gt 0 ]; then
    default_choice="1"
  else
    default_choice="3"
  fi

  read -r -p "Select [${default_choice}]: " choice
  choice="${choice:-$default_choice}"

  case "$choice" in
    1)
      install_existing_skill_roots
      ;;
    2)
      echo
      echo "Enter target numbers or ids, separated by spaces."
      echo "Examples: 1 2    or    codex claude agy"
      read -r -p "Targets: " numbers

      for token in $numbers; do
        case "$token" in
          1) selected_ids="$selected_ids generic" ;;
          2) selected_ids="$selected_ids codex" ;;
          3) selected_ids="$selected_ids claude" ;;
          4) selected_ids="$selected_ids agy" ;;
          generic|codex|claude|agy) selected_ids="$selected_ids $token" ;;
          *)
            echo "Unknown selection '$token'" >&2
            return 2
            ;;
        esac
      done

      if [ -z "${selected_ids// }" ]; then
        echo "No skill targets selected. Skipping skill install."
      else
        install_selected_skill_roots "$selected_ids"
      fi
      ;;
    3)
      echo "Skipping agent skill install."
      ;;
    4)
      install_all_skill_roots
      ;;
    *)
      echo "Invalid choice: $choice" >&2
      return 2
      ;;
  esac
}

configure_skill_install() {
  if [ ! -f "$skill_source" ]; then
    echo "Skill source not found: $skill_source. Skipping skill install." >&2
    return 0
  fi

  case "${AI_GH_INSTALL_SKILLS:-}" in
    none|skip|false|0)
      echo "Skipping agent skill install because AI_GH_INSTALL_SKILLS=${AI_GH_INSTALL_SKILLS}."
      return 0
      ;;
    existing)
      install_existing_skill_roots
      return 0
      ;;
    all)
      install_all_skill_roots
      return 0
      ;;
    generic|codex|claude|agy|*,*)
      install_selected_skill_roots "$AI_GH_INSTALL_SKILLS"
      return 0
      ;;
    "")
      ;;
    *)
      echo "Invalid AI_GH_INSTALL_SKILLS value: $AI_GH_INSTALL_SKILLS" >&2
      echo "Use: none, existing, all, or comma-separated ids: generic,codex,claude,agy" >&2
      return 2
      ;;
  esac

  if [ -t 0 ]; then
    prompt_skill_install
  else
    install_existing_skill_roots
  fi
}

real_gh="$(find_real_gh || true)"

if [ -z "$real_gh" ]; then
  echo "Cannot find real gh binary. Install GitHub CLI first." >&2
  exit 1
fi

printf "%s\n" "$real_gh" > "$HOME/.config/ai-gh/real-gh-path"

install -m 0755 bin/gh "$HOME/.local/bin/gh"
install -m 0755 bin/ai-gh-init "$HOME/.local/bin/ai-gh-init"

configure_skill_install

if ! printf "%s" "$PATH" | grep -q "$HOME/.local/bin"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  echo "Added ~/.local/bin to ~/.zshrc"
fi

echo
echo "Installed ai-gh-account-router."
echo "Real gh:  $real_gh"
echo "Wrapper:  $HOME/.local/bin/gh"
echo "Init:     $HOME/.local/bin/ai-gh-init"

if [ -n "$installed_skill_dirs" ]; then
  echo "Skills installed:${installed_skill_dirs}"
else
  echo "Skills:   none installed"
fi

if [ -n "$skipped_skill_dirs" ]; then
  echo "Missing skill roots skipped:${skipped_skill_dirs}"
fi

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
