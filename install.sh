#!/usr/bin/env bash
# install.sh — install the opencode-workflow skills into the user's
# opencode skills directory ($OPENCODE_CONFIG_DIR/skills, default ~/.config/opencode/skills).
#
# Usage:
#   bash install.sh                  # symlink each skill (recommended)
#   bash install.sh --copy           # copy instead of symlinking (cuts
#                                    # the link to git pull updates)
#   bash install.sh --dry-run        # show what would happen
#
# Idempotent — re-running with no changes produces "already linked"
# log lines and exits 0. Refuses to clobber non-symlink directories
# at the destination.
#
# This script is invoked once after cloning opencode-workflow. After it
# runs, opencode auto-discovers the skills on its next session start.

set -uo pipefail

# Colors for output (skip if not a tty)
if [ -t 1 ]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RESET=$'\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  RESET=""
fi

# ─────────────────────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────────────────────

MODE="symlink"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --copy)    MODE="copy"  ;;
    --symlink) MODE="symlink" ;;
    --dry-run) DRY_RUN=1     ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "${RED}error:${RESET} unknown argument: $arg"
      exit 2
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Resolve paths
# ─────────────────────────────────────────────────────────────────────────────

# Scaffolder root: directory containing this script.
SCAFFOLDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# opencode skills directory (per Phase 0 ADR-0001 D1; verified against opencode-cli 0.130.0).
OPENCODE_SKILLS_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/skills"

# Sanity: the scaffolder must contain the expected skills.
if [ ! -d "$SCAFFOLDER_ROOT/skills/agentic-apps-workflow" ]; then
  echo "${RED}error:${RESET} install.sh must be run from the opencode-workflow root."
  echo "       expected: $SCAFFOLDER_ROOT/skills/agentic-apps-workflow/"
  exit 1
fi

# opencode installed?
if ! command -v opencode >/dev/null 2>&1; then
  echo "${YELLOW}warn:${RESET} 'opencode' CLI not found on PATH."
  echo "      Continuing with skill install, but you'll need to install opencode"
  echo "      before the skills are usable. See https://opencode.ai/docs/"
fi

# Refresh the agenticapps-shared submodule (provides the migration test harness
# primitives). Idempotent and non-fatal: a missing/transient submodule must not
# block skill linking. Guard on a real .git so copied/tarball trees (which carry
# .gitmodules but no git dir) don't fatal under the refresh.
if [ "$DRY_RUN" -eq 0 ] && [ -f "$SCAFFOLDER_ROOT/.gitmodules" ] \
   && { [ -d "$SCAFFOLDER_ROOT/.git" ] || [ -f "$SCAFFOLDER_ROOT/.git" ]; }; then
  echo "${YELLOW}note:${RESET} syncing git submodule(s) vendor/agenticapps-shared..."
  if ! { git -C "$SCAFFOLDER_ROOT" submodule sync --recursive \
      && git -C "$SCAFFOLDER_ROOT" submodule update --init --recursive; }; then
    echo "${YELLOW}warn:${RESET} submodule refresh failed — continuing with skill linking." >&2
    echo "      Fix later: git -C \"$SCAFFOLDER_ROOT\" submodule update --init --recursive" >&2
  fi
fi

# Ensure destination exists.
if [ ! -d "$OPENCODE_SKILLS_DIR" ]; then
  echo "${YELLOW}note:${RESET} creating $OPENCODE_SKILLS_DIR"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$OPENCODE_SKILLS_DIR"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Install each skill directory
# ─────────────────────────────────────────────────────────────────────────────

INSTALLED=0
SKIPPED=0
FAILED=0

install_one() {
  local src="$1"
  local name
  name="$(basename "$src")"
  local dst="$OPENCODE_SKILLS_DIR/$name"

  # NB: test -L before -e. A dangling symlink (target moved/deleted — e.g. the
  # repo was relocated) makes `-e` false because it follows the link, which
  # would skip replacement and leave `ln -s` to fail "File exists". Catch the
  # symlink first so stale/dangling links are always repointed.
  if [ -L "$dst" ]; then
    local target
    target="$(readlink "$dst")"
    if [ "$target" = "$src" ]; then
      echo "  ${GREEN}OK${RESET}     $name (already linked)"
      SKIPPED=$((SKIPPED+1))
      return
    else
      echo "  ${YELLOW}REPLACE${RESET} $name (was linked to $target)"
      if [ "$DRY_RUN" -eq 0 ]; then
        rm "$dst"
      fi
    fi
  elif [ -e "$dst" ]; then
    echo "  ${RED}BLOCKED${RESET} $name (destination exists and is not a symlink — refusing to clobber)"
    FAILED=$((FAILED+1))
    return
  fi

  case "$MODE" in
    symlink)
      if [ "$DRY_RUN" -eq 0 ]; then
        ln -s "$src" "$dst"
      fi
      echo "  ${GREEN}LINK${RESET}   $name -> $src"
      ;;
    copy)
      if [ "$DRY_RUN" -eq 0 ]; then
        cp -R "$src" "$dst"
      fi
      echo "  ${GREEN}COPY${RESET}   $name <- $src"
      ;;
  esac
  INSTALLED=$((INSTALLED+1))
}

echo ""
echo "${YELLOW}Installing opencode-workflow skills (mode: $MODE; dry-run: $DRY_RUN)${RESET}"
echo "  scaffolder: $SCAFFOLDER_ROOT"
echo "  destination: $OPENCODE_SKILLS_DIR"
echo ""

for d in "$SCAFFOLDER_ROOT"/skills/*/; do
  d="${d%/}"
  install_one "$d"
done

# ─────────────────────────────────────────────────────────────────────────────
# VERSION: ensure the scaffolder's root VERSION is resolvable next to each
# skill's snapshot. The setup skill reads .../<skill>/VERSION as the single
# source of truth for $LATEST, but the repo ships VERSION at its root (one
# level above the skill dirs), so link/copy it into every skill that has a
# snapshot/ directory. Idempotent.
#
# Symlink mode: $dst is a symlink to the source $d, so writing $dst/VERSION
#   resolves through into the source tree as a relative ../../VERSION link.
# Copy mode:    $dst is a real copied dir, so VERSION is copied as a real file.
# ─────────────────────────────────────────────────────────────────────────────
VERSION_SRC="$SCAFFOLDER_ROOT/VERSION"
if [ -f "$VERSION_SRC" ]; then
  for d in "$SCAFFOLDER_ROOT"/skills/*/; do
    d="${d%/}"
    [ -d "$d/snapshot" ] || continue
    name="$(basename "$d")"
    dst="$OPENCODE_SKILLS_DIR/$name"
    # `[ -e ]` follows symlinks, so a dangling copy-mode symlink counts as
    # missing and gets replaced below. Force flags let a stale link be repointed.
    if [ -e "$dst/VERSION" ]; then
      echo "  ${GREEN}OK${RESET}     $name/VERSION (already present)"
      continue
    fi
    if [ "$DRY_RUN" -eq 0 ]; then
      if [ "$MODE" = "copy" ]; then
        cp -f "$VERSION_SRC" "$dst/VERSION"
      else
        ln -sf "../../VERSION" "$dst/VERSION"
      fi
    fi
    echo "  ${GREEN}VERSION${RESET} $name/VERSION -> $(cat "$VERSION_SRC")"
  done
else
  echo "${YELLOW}warn:${RESET} $VERSION_SRC missing — skill VERSION resolution will fall back to SKILL.md frontmatter."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Slash commands — so `/setup-agenticapps-workflow` and `/update-…` exist in the
# TUI. Skills are only reachable via the skill tool / natural language; commands
# give the familiar `/name` entry point (like GSD's /gsd-*).
# ─────────────────────────────────────────────────────────────────────────────
OPENCODE_COMMANDS_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/commands"
if [ -d "$SCAFFOLDER_ROOT/commands" ]; then
  [ -d "$OPENCODE_COMMANDS_DIR" ] || { echo "${YELLOW}note:${RESET} creating $OPENCODE_COMMANDS_DIR"; [ "$DRY_RUN" -eq 0 ] && mkdir -p "$OPENCODE_COMMANDS_DIR"; }
  for c in "$SCAFFOLDER_ROOT"/commands/*.md; do
    [ -e "$c" ] || continue
    name="$(basename "$c")"
    dst="$OPENCODE_COMMANDS_DIR/$name"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$c" ]; then
      echo "  ${GREEN}OK${RESET}     command $name (already linked)"
    elif [ -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "  ${RED}BLOCKED${RESET} command $name (exists, not a symlink)"
    else
      [ "$DRY_RUN" -eq 0 ] && { rm -f "$dst"; ln -s "$c" "$dst"; }
      echo "  ${GREEN}LINK${RESET}   command $name -> /${name%.md}"
    fi
  done
fi

# ─────────────────────────────────────────────────────────────────────────────
# Templates: no secondary symlink needed (v0.2.0 fix)
# ─────────────────────────────────────────────────────────────────────────────
# Templates now ship INSIDE the setup skill at
# skills/setup-opencode-agenticapps-workflow/templates/ and are committed there.
# Because the whole setup-skill directory is symlinked above, migrations resolve
# them at the stable path
# $OPENCODE_CONFIG_DIR/skills/setup-opencode-agenticapps-workflow/templates/ with NO
# install-time write inside the source tree. (Pre-v0.2.0, install.sh wrote a
# secondary symlink there which resolved back into the repo — that step is gone.)

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "${YELLOW}Summary${RESET}"
echo "  ${GREEN}installed/linked${RESET}: $INSTALLED"
echo "  ${YELLOW}skipped (already done)${RESET}: $SKIPPED"
[ $FAILED -gt 0 ] && echo "  ${RED}failed${RESET}: $FAILED"

if [ $FAILED -gt 0 ]; then
  echo ""
  echo "${RED}install incomplete${RESET} — see blocked entries above."
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Bind upstream — OpenSpec (planning front end) + Superpowers (execution)
# ─────────────────────────────────────────────────────────────────────────────
# opencode-workflow ships only the AgenticApps layer. Under spec v1.0.0 the
# planning front end is OpenSpec, bound UPSTREAM and generated per project by its
# CLI (spec §16) — this repo does not re-port it. Superpowers loads via the
# opencode.json "plugin" entry. The §18 change-gate is installed here: the
# host-agnostic shell script (the real enforcement surface), the opencode
# tool.execute.before plugin, and this repo's git pre-commit floor. Pass
# --skip-upstream to install only the AgenticApps skills.
SKIP_UPSTREAM=0
for arg in "$@"; do [ "$arg" = "--skip-upstream" ] && SKIP_UPSTREAM=1; done

AA_BIN="$HOME/.agenticapps/bin"
OPENCODE_PLUGIN_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/plugin"

echo ""
echo "${YELLOW}Installing the OpenSpec change-gate (spec §18)${RESET}"
echo "  ${GREEN}GATE${RESET}   $AA_BIN/openspec-change-gate.sh   (host-agnostic enforcement surface)"
echo "  ${GREEN}GATE${RESET}   $AA_BIN/reviewer-cli.sh           (reviewer-CLI wrapper)"
echo "  ${GREEN}HOOK${RESET}   $OPENCODE_PLUGIN_DIR/openspec-change-gate.ts  (opencode tool.execute.before)"
echo "  ${GREEN}HOOK${RESET}   .git/hooks/pre-commit             (agent-agnostic floor)"
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$AA_BIN" "$OPENCODE_PLUGIN_DIR"
  install -m 0755 "$SCAFFOLDER_ROOT/bin/openspec-change-gate.sh" "$AA_BIN/openspec-change-gate.sh"
  install -m 0755 "$SCAFFOLDER_ROOT/bin/reviewer-cli.sh"         "$AA_BIN/reviewer-cli.sh"
  install -m 0644 "$SCAFFOLDER_ROOT/bin/openspec-change-gate.ts" "$OPENCODE_PLUGIN_DIR/openspec-change-gate.ts"
  if [ -d "$SCAFFOLDER_ROOT/.git" ] || [ -f "$SCAFFOLDER_ROOT/.git" ]; then
    hookrel="$(git -C "$SCAFFOLDER_ROOT" rev-parse --git-path hooks 2>/dev/null)"
    if [ -n "$hookrel" ]; then
      ( cd "$SCAFFOLDER_ROOT" && mkdir -p "$hookrel" && install -m 0755 bin/git-hooks/pre-commit "$hookrel/pre-commit" ) \
        && echo "  ${GREEN}OK${RESET}     pre-commit installed into $hookrel/"
    fi
  fi
fi

# OpenSpec front end: init the slot + generate the /opsx:* commands for this repo
# (dogfood). Per-project init is what the setup skill runs in TARGET repos.
echo ""
echo "${YELLOW}Binding OpenSpec — openspec init --tools opencode --profile core${RESET} (generates openspec/ slot + /opsx:* commands)"
if [ "$DRY_RUN" -eq 0 ] && [ "$SKIP_UPSTREAM" -eq 0 ]; then
  if command -v openspec >/dev/null 2>&1; then
    if [ ! -d "$SCAFFOLDER_ROOT/openspec" ]; then
      ( cd "$SCAFFOLDER_ROOT" && openspec init --tools opencode --profile core --force ) \
        && echo "  ${GREEN}OK${RESET}     openspec slot + /opsx:* commands generated" \
        || echo "${YELLOW}warn:${RESET} openspec init failed — run it manually in this repo."
    else
      echo "  ${GREEN}OK${RESET}     openspec/ already present (skipping init)"
    fi
  else
    echo "${YELLOW}warn:${RESET} openspec CLI not found — install it, then re-run:"
    echo "      npm i -g @fission-ai/openspec && openspec init --tools opencode --profile core"
  fi
  echo ""
  echo "${YELLOW}Superpowers${RESET} is wired via the \"plugin\" entry in opencode.json"
  echo "  (superpowers@git+https://github.com/obra/superpowers.git) — opencode loads it on restart."
fi

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "${YELLOW}dry-run only${RESET} — no changes written."
else
  echo "${GREEN}done.${RESET} Restart opencode (or open a fresh session) to pick up everything."
  echo ""
  echo "Next:"
  echo "  - Open a change:                    /opsx:propose \"<idea>\""
  echo "  - In a fresh project:               \$setup-opencode-agenticapps-workflow"
  echo "  - In an existing installed project: \$update-opencode-agenticapps-workflow"
  echo "  - Workflow explainer + caveats:     docs/WORKFLOW.md · docs/BINDING.md"
fi
