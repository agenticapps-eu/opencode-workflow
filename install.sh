#!/usr/bin/env bash
# install.sh — install the opencode-workflow skills into the user's
# opencode skills directory ($OPENCODE_CONFIG_DIR/skills, default ~/.config/opencode/skills).
#
# Usage:
#   bash install.sh                  # symlink each skill (recommended)
#   bash install.sh --copy           # copy instead of symlinking (cuts
#                                    # the link to git pull updates)
#   bash install.sh --dry-run        # show what would happen
#   bash install.sh --skip-upstream  # install only the AgenticApps skills
#                                    # (do not bind OpenSpec / Superpowers)
#   bash install.sh --install-prereqs # authorise installing a missing
#                                    # prerequisite without being asked
#                                    # (env: AGENTICAPPS_INSTALL_PREREQS=1)
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
# spec §21 — the opt-in that authorises a consent-requiring install unattended.
# Both spellings are fixed by the section rather than chosen here: the
# non-interactive report has to name the flag that authorises the install, and
# four hosts inventing four spellings is the divergence §21 exists to remove.
INSTALL_PREREQS=0
case "${AGENTICAPPS_INSTALL_PREREQS:-0}" in 1|true|yes) INSTALL_PREREQS=1 ;; esac
# Set when a step the operator asked for did not happen. §21: an installer that
# silently omits a step exits 0 having done less than the operator believes,
# and a zero exit is what an automated caller reads.
SKIPPED=0

for arg in "$@"; do
  case "$arg" in
    --copy)    MODE="copy"  ;;
    --symlink) MODE="symlink" ;;
    --dry-run) DRY_RUN=1     ;;
    # Documented since this flag was introduced, and rejected by this parser
    # ever since: it is read by a second loop further down, which never runs
    # because `*)` exits 2 first.
    --skip-upstream) ;;
    --install-prereqs) INSTALL_PREREQS=1 ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0
      ;;
    *)
      echo "${RED}error:${RESET} unknown argument: $arg"
      exit 2
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Consent (spec §21)
# ─────────────────────────────────────────────────────────────────────────────
# A write that can change software this workflow did not install is offered,
# never performed unasked. Installing a package into npm's global namespace is
# that kind of write: it can upgrade or replace something every other project
# on the machine resolves. Provisioning this repo, and writing into
# ~/.agenticapps/, are not — the operator asked for those by running this.
#
# Returns 0 if the operator accepted, 1 otherwise. Only an explicit y/yes
# counts. Empty input, anything unrecognised, and end-of-input all decline,
# because a declined install is recoverable by re-running and an unwanted
# global install is not.
prereq_consent() { # $1 = prerequisite name, $2 = the command that installs it
  local reply
  if [ "$INSTALL_PREREQS" -eq 1 ]; then
    echo "${YELLOW}note:${RESET} installing $1 — authorised by --install-prereqs"
    echo "      $2"
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "${YELLOW}warn:${RESET} $1 is missing, and there is no terminal to ask on."
    echo "      it would be installed with: $2"
    echo "      to authorise that unattended, re-run with --install-prereqs"
    echo "      or set AGENTICAPPS_INSTALL_PREREQS=1."
    return 1
  fi
  echo "${YELLOW}note:${RESET} $1 is not installed. This installer can install it with:"
  echo "      $2"
  echo "      That changes a global package other projects on this machine resolve."
  printf '      install it now? [y/N] '
  IFS= read -r reply || reply=""
  case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) echo "      declined." ; return 1 ;;
  esac
}

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
# git is a declared prerequisite. §21 requires reporting a missing one BY NAME,
# with what will not work without it — and git is a system runtime, so it is
# reported and never offered: installing one is platform-dependent in ways a
# shell script handles badly. Without this check the failure surfaces further
# down as git's own "command not found", which names the symptom.
if ! command -v git >/dev/null 2>&1; then
  echo "${YELLOW}warn:${RESET} 'git' not found on PATH."
  echo "      the vendor/agenticapps-shared submodule refresh and this repo's own"
  echo "      pre-commit wiring will be skipped. Skill installation still works."
  echo "      git is a system runtime — install it with your OS package manager."
  SKIPPED=1
fi

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

# >>> gate-version-arbitration >>>
# Every host writes to the SHARED ~/.agenticapps/bin/openspec-change-gate.sh, so
# without arbitration it is last-writer-wins: a host vendoring an older gate would
# silently republish it over a newer one (issue #15 / core#32). This installer
# reads the `# gate-version:` marker and refuses to downgrade. It makes THIS
# installer non-downgrading; machine-wide monotonicity needs every host to do the
# same (core#34). Marker-delimited + self-contained so the test suite can source it.
_gate_version_of() {  # <file> -> dotted version on stdout; unmarked/unreadable/malformed -> 0.0.0
  local f="$1" v=""
  [ -r "$f" ] && v="$(sed -n 's/^# gate-version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$f" | head -1)"
  case "$v" in ''|*[!0-9.]*) v="0.0.0" ;; esac
  printf '%s' "$v"
}
_gate_ver_ge() {  # returns 0 (true) if $1 >= $2, comparing up to 3 numeric dotted fields
  local a b; local -a A B; local IFS=.
  # shellcheck disable=SC2206
  A=($1); B=($2)
  local i ai bi
  for i in 0 1 2; do
    ai=${A[i]:-0}; bi=${B[i]:-0}
    ai=$((10#${ai%%[!0-9]*})); bi=$((10#${bi%%[!0-9]*}))
    [ "$ai" -gt "$bi" ] && return 0
    [ "$ai" -lt "$bi" ] && return 1
  done
  return 0  # equal -> ge
}
_gate_should_install() {  # <incoming_file> <installed_file>: 0 (true) => replace, 1 => keep
  [ -e "$2" ] || return 0                                   # nothing installed -> install
  _gate_ver_ge "$(_gate_version_of "$2")" "$(_gate_version_of "$1")" && return 1  # installed >= incoming -> keep
  return 0                                                   # installed < incoming -> replace
}
# <<< gate-version-arbitration <<<

# >>> reviewer-cli-version-arbitration >>>
# The §18 review-producer wrapper reviewer-cli.sh is written to the SAME shared
# ~/.agenticapps/bin/reviewer-cli.sh by every host installer, so — exactly like
# the gate above — an unarbitrated write is last-writer-wins: a host vendoring an
# older wrapper silently republishes it over a newer one and drops vendor arms
# for every agent on the machine (core#41: a 3-arm copy blind-installed over the
# 4-arm one; the next review asking for `opencode` got `unknown vendor`). This
# installer reads the `# reviewer-cli-version:` marker and refuses to downgrade,
# reusing the gate region's _gate_ver_ge comparator (the compare is
# marker-agnostic; only the extraction differs). Marker-delimited + self-contained
# so the test suite can source it alongside the gate region.
_reviewer_cli_version_of() {  # <file> -> dotted version on stdout; unmarked/unreadable/malformed -> 0.0.0
  local f="$1" v=""
  [ -r "$f" ] && v="$(sed -n 's/^# reviewer-cli-version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$f" | head -1)"
  case "$v" in ''|*[!0-9.]*) v="0.0.0" ;; esac
  printf '%s' "$v"
}
_reviewer_cli_should_install() {  # <incoming_file> <installed_file>: 0 (true) => replace, 1 => keep
  [ -e "$2" ] || return 0                                   # nothing installed -> install
  _gate_ver_ge "$(_reviewer_cli_version_of "$2")" "$(_reviewer_cli_version_of "$1")" && return 1  # installed >= incoming -> keep
  return 0                                                   # installed < incoming -> replace
}
# <<< reviewer-cli-version-arbitration <<<

echo ""
echo "${YELLOW}Installing the OpenSpec change-gate (spec §18)${RESET}"
echo "  ${GREEN}GATE${RESET}   $AA_BIN/openspec-change-gate.sh   (host-agnostic enforcement surface)"
echo "  ${GREEN}GATE${RESET}   $AA_BIN/reviewer-cli.sh           (reviewer-CLI wrapper)"
echo "  ${GREEN}HOOK${RESET}   $OPENCODE_PLUGIN_DIR/openspec-change-gate.ts  (opencode tool.execute.before)"
echo "  ${GREEN}HOOK${RESET}   .git/hooks/pre-commit             (agent-agnostic floor)"

# ── where the gate and the wrapper come from (ADR-0013) ──────────────────────
# This repo does NOT vendor them. tools/core-vendor.manifest records WHICH core
# revision it trusts and WHAT each file must hash to; materialise-core-artifacts.sh
# turns that into verified bytes at bin/, and the arbitration above then decides
# whether to publish them into the shared $AA_BIN.
#
# bin/ is a CACHE, not source: both files are gitignored and regenerated from the
# pin, so they cannot drift. Vendoring is what this replaced — the copies existed
# only to feed this script, and on 2026-07-31 they were gate 1.3.1 against core's
# 2.0.0 and wrapper 1.1.0 against 1.2.0. Arbitration meant that was never
# destructive, only silently useless: a fresh machine installed from this host
# alone got the OLD gate and nothing said so.
#
# Fails CLOSED. An installer that cannot verify what it is about to publish into
# a directory shared by every agent on this machine must stop. It does NOT fall
# back to a copy on disk — that fallback, run today, would republish 1.3.1 over
# 2.0.0 for every agent here.
if [ "$DRY_RUN" -eq 0 ]; then
  if ! "$SCAFFOLDER_ROOT/bin/materialise-core-artifacts.sh"; then
    echo "  ${RED}FAIL${RESET}   could not materialise core's artifacts from the pin."
    echo "           Nothing was published. Fix the pin or the source, then re-run."
    echo "           Offline with no core checkout? Clone core beside this repo, or"
    echo "           set CORE_CHECKOUT=/path/to/agenticapps-workflow-core."
    exit 1
  fi
  echo "  ${GREEN}PIN${RESET}    core artifacts materialised from $(sed -n 's/^core_commit=\(.\{7\}\).*/\1/p' "$SCAFFOLDER_ROOT/tools/core-vendor.manifest")"
else
  # Dry-run writes nothing, including to the cache. Report whether the cache is
  # already current instead — an accurate "would resolve" beats a silent write.
  if "$SCAFFOLDER_ROOT/bin/materialise-core-artifacts.sh" --check 2>/dev/null; then
    echo "  ${GREEN}PIN${RESET}    core artifacts already match the pin (nothing to resolve)"
  else
    echo "  ${YELLOW}PIN${RESET}    would resolve core's gate + wrapper from tools/core-vendor.manifest"
  fi
fi

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$AA_BIN" "$OPENCODE_PLUGIN_DIR" "$HOME/.agenticapps/git-hooks"
  # Gate: install only if this is not a downgrade of the shared copy (issue #15).
  if _gate_should_install "$SCAFFOLDER_ROOT/bin/openspec-change-gate.sh" "$AA_BIN/openspec-change-gate.sh"; then
    install -m 0755 "$SCAFFOLDER_ROOT/bin/openspec-change-gate.sh" "$AA_BIN/openspec-change-gate.sh"
    echo "  ${GREEN}OK${RESET}     gate installed (version $(_gate_version_of "$AA_BIN/openspec-change-gate.sh"))"
  else
    echo "  ${GREEN}KEEP${RESET}   gate at $AA_BIN is version $(_gate_version_of "$AA_BIN/openspec-change-gate.sh") >= incoming $(_gate_version_of "$SCAFFOLDER_ROOT/bin/openspec-change-gate.sh") — refused downgrade"
  fi
  # Reviewer-CLI wrapper: same downgrade-refusal as the gate (core#41). Every
  # host writes this shared path; refuse to replace a newer copy with an older one.
  if _reviewer_cli_should_install "$SCAFFOLDER_ROOT/bin/reviewer-cli.sh" "$AA_BIN/reviewer-cli.sh"; then
    install -m 0755 "$SCAFFOLDER_ROOT/bin/reviewer-cli.sh" "$AA_BIN/reviewer-cli.sh"
    echo "  ${GREEN}OK${RESET}     reviewer-cli installed (version $(_reviewer_cli_version_of "$AA_BIN/reviewer-cli.sh"))"
  else
    echo "  ${GREEN}KEEP${RESET}   reviewer-cli at $AA_BIN is version $(_reviewer_cli_version_of "$AA_BIN/reviewer-cli.sh") >= incoming $(_reviewer_cli_version_of "$SCAFFOLDER_ROOT/bin/reviewer-cli.sh") — refused downgrade"
  fi
  install -m 0644 "$SCAFFOLDER_ROOT/bin/openspec-change-gate.ts" "$OPENCODE_PLUGIN_DIR/openspec-change-gate.ts"
  # Stage the pre-commit at a stable global path so the per-project setup skill
  # can install it into each target repo's .git/hooks.
  install -m 0755 "$SCAFFOLDER_ROOT/bin/git-hooks/pre-commit"    "$HOME/.agenticapps/git-hooks/pre-commit"
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
  # openspec is this front end's core dependency, and it used to be installed
  # automatically on that reasoning. Being a dependency is not the question §21
  # asks: `npm i -g` mutates a namespace shared with software this workflow did
  # not install, so it is offered and never performed unasked. Instructing
  # without installing would also be conformant; asking is the option the
  # operator most likely wants.
  if ! command -v openspec >/dev/null 2>&1; then
    OPENSPEC_INSTALL="npm i -g @fission-ai/openspec"
    if ! command -v npm >/dev/null 2>&1; then
      echo "${YELLOW}warn:${RESET} openspec CLI and npm are both absent."
      echo "      npm is a system runtime — this installer will not install it."
      echo "      Install Node.js, then: $OPENSPEC_INSTALL"
      SKIPPED=1
    elif prereq_consent "openspec" "$OPENSPEC_INSTALL"; then
      if npm i -g @fission-ai/openspec; then
        echo "  ${GREEN}OK${RESET}     installed openspec (@fission-ai/openspec, global)"
      else
        rc=$?
        echo "${RED}error:${RESET} $OPENSPEC_INSTALL failed (exit $rc)." >&2
        echo "      openspec is still absent — this is not being treated as installed." >&2
        SKIPPED=1
      fi
    else
      SKIPPED=1
      echo "      skipped: the openspec/ slot will not be generated. Complete it later with:"
      echo "        $OPENSPEC_INSTALL"
      echo "        openspec init --tools opencode --profile core"
    fi
  fi
  if command -v openspec >/dev/null 2>&1; then
    if [ ! -d "$SCAFFOLDER_ROOT/openspec" ]; then
      ( cd "$SCAFFOLDER_ROOT" && openspec init --tools opencode --profile core --force ) \
        && echo "  ${GREEN}OK${RESET}     openspec slot + /opsx:* commands generated" \
        || echo "${YELLOW}warn:${RESET} openspec init failed — run it manually in this repo."
    else
      echo "  ${GREEN}OK${RESET}     openspec/ already present (skipping init)"
    fi
  else
    echo "${YELLOW}warn:${RESET} openspec still unavailable — the change-gate will BLOCK edits under an"
    echo "      active change until it is installed (an unvalidatable change must not pass, §18)."
  fi
  echo ""
  echo "${YELLOW}Superpowers${RESET} is wired via the \"plugin\" entry in opencode.json"
  echo "  (superpowers@git+https://github.com/obra/superpowers.git) — opencode loads it on restart."
fi

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "${YELLOW}dry-run only${RESET} — no changes written."
elif [ "$SKIPPED" -eq 1 ]; then
  # §21 — completed work and skipped work are reported as different things, and
  # the exit status says which happened. Reporting alone is not sufficient: a
  # zero exit is what an automated caller reads.
  echo "${YELLOW}done, with skipped steps.${RESET} The skills are installed; the steps"
  echo "named above did not run. Re-run this installer once their prerequisites"
  echo "are present."
  exit 1
else
  echo "${GREEN}done.${RESET} Restart opencode (or open a fresh session) to pick up everything."
  echo ""
  echo "Next:"
  echo "  - Open a change:                    /opsx:propose \"<idea>\""
  echo "  - In a fresh project:               \$setup-opencode-agenticapps-workflow"
  echo "  - In an existing installed project: \$update-opencode-agenticapps-workflow"
  echo "  - Workflow explainer + caveats:     docs/WORKFLOW.md · docs/BINDING.md"
fi
