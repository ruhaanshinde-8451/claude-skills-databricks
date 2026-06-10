#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="${HOME}/.copilot/skills"
FORCE="false"
SKILL_NAME=""
MODE="personal"
SKILLS_REPO="${SKILLS_REPO:-ruhaanshinde-8451/claude-skills-databricks}"
SKILLS_REF="${SKILLS_REF:-main}"

if [[ -n "${BASH_SOURCE[0]-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(pwd)"
fi

PLUGINS_DIR="${SCRIPT_DIR}/plugins"
TEMP_DIR=""

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  ./install-skills.sh [--skill <skill-name>] [--force] [--project]

Options:
  --skill <skill-name>  Install only one skill by directory name (for example: deploy-dab)
  --force               Replace existing installed skill directory
  --project             Install into .github/skills in the current repo instead of ~/.copilot/skills
  -h, --help            Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      SKILL_NAME="${2:-}"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --project)
      MODE="project"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" == "project" ]]; then
  TARGET_DIR="$(pwd)/.github/skills"
fi

if [[ ! -d "$PLUGINS_DIR" ]]; then
  TEMP_DIR="$(mktemp -d)"
  tarball_url="https://codeload.github.com/${SKILLS_REPO}/tar.gz/${SKILLS_REF}"

  echo "Local plugins directory not found. Downloading from ${SKILLS_REPO}@${SKILLS_REF}..."
  curl -fsSL "$tarball_url" | tar -xzf - -C "$TEMP_DIR"

  downloaded_plugins="$(find "$TEMP_DIR" -type d -path '*/plugins' | head -n 1)"
  if [[ -z "$downloaded_plugins" ]]; then
    echo "Failed to locate plugins directory in downloaded archive."
    exit 1
  fi

  PLUGINS_DIR="$downloaded_plugins"
fi

mkdir -p "$TARGET_DIR"

skill_dirs=()
while IFS= read -r path; do
  skill_dirs+=("$path")
done < <(find "$PLUGINS_DIR" -name "SKILL.md" -exec dirname {} \;)

if [[ "${#skill_dirs[@]}" -eq 0 ]]; then
  echo "No skills found under $PLUGINS_DIR"
  exit 1
fi

installed=0
for src in "${skill_dirs[@]}"; do
  skill_dir_name="$(basename "$src")"

  if [[ -n "$SKILL_NAME" && "$skill_dir_name" != "$SKILL_NAME" ]]; then
    continue
  fi

  dst="${TARGET_DIR}/${skill_dir_name}"
  if [[ -d "$dst" ]]; then
    if [[ "$FORCE" != "true" ]]; then
      echo "Skipping existing skill: $skill_dir_name (use --force to replace)"
      continue
    fi
    rm -rf "$dst"
  fi

  cp -R "$src" "$dst"
  echo "Installed: $skill_dir_name -> $dst"
  installed=$((installed + 1))
done

if [[ "$installed" -eq 0 ]]; then
  if [[ -n "$SKILL_NAME" ]]; then
    echo "No skill installed. Skill not found or already installed: $SKILL_NAME"
  else
    echo "No skills installed."
  fi
  exit 1
fi

echo "Done. In Copilot CLI run /skills reload (or start a new session)."
