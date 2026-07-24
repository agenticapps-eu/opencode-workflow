// openspec-change-gate.ts — opencode wiring for the §18 OpenSpec change-gate.
//
// opencode has no PreToolUse setting; its host-equivalent interposition point
// (spec §18) is a plugin `tool.execute.before` hook. This plugin is thin: it
// hands the tool-call to the host-agnostic enforcement script
// (~/.agenticapps/bin/openspec-change-gate.sh — the real source of truth, §18)
// and BLOCKS the edit by THROWING when the script exits 2. Everything else
// (the truth table, validate + REVIEWS.md >=2, escape hatch, fail-open) lives
// in the shell script so every host enforces identical behavior.
//
// Mechanism precedent: an observe-only tool.execute.after plugin already ships
// in this fleet's opencode config. This one uses tool.execute.before and can
// DENY, because throwing from a before-hook aborts the tool call.
//
// A hook cannot gate the session that installed it (opencode loads plugins at
// session start) — so this enforces live for the NEXT session; the git
// pre-commit hook + CI are the floor that also covers the installing session.
//
// Kill switch: export OPENSPEC_GATE_DISABLED=1   (fail-open, no gating)
// Escape hatch (per-edit, logged): export GSD_SKIP_REVIEWS=1  (handled in the .sh)
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { homedir } from "node:os";
import { existsSync } from "node:fs";

// File-mutating opencode tools this gate inspects.
const MUTATORS = new Set(["edit", "write", "patch", "multiedit"]);

function gateScript(): string | null {
  const override = process.env.OPENSPEC_CHANGE_GATE;
  const candidates = [
    override,
    join(homedir(), ".agenticapps", "bin", "openspec-change-gate.sh"),
  ].filter(Boolean) as string[];
  for (const c of candidates) if (existsSync(c)) return c;
  return null;
}

function pathFromArgs(args: any): string | undefined {
  if (!args || typeof args !== "object") return undefined;
  return args.filePath ?? args.path ?? args.file ?? args.file_path;
}

export const OpenspecChangeGate = async ({ directory, worktree }: any = {}) => ({
  "tool.execute.before": async (
    input: { tool: string; sessionID: string; callID: string },
    output: { args: any },
  ) => {
    // Kill switch — fail open, no gating.
    if (process.env.OPENSPEC_GATE_DISABLED === "1") return;

    // Only gate file-mutating tools.
    if (!MUTATORS.has(input.tool)) return;

    const script = gateScript();
    if (!script) return; // not installed → fail open (never brick the host)

    const filePath = pathFromArgs(output?.args);
    if (!filePath) return; // nothing to gate → fail open (parse error posture)

    const cwd = worktree || directory || process.cwd();
    const payload = JSON.stringify({
      tool: input.tool,
      tool_input: { file_path: filePath },
    });

    let rc = 0;
    try {
      const res = spawnSync("bash", [script], {
        cwd,
        input: payload,
        encoding: "utf8",
        timeout: 60_000,
      });
      // If the gate itself errored (couldn't run), fail open — do not brick edits.
      if (res.error) return;
      rc = res.status ?? 0;
      if (res.stderr) process.stderr.write(res.stderr);
    } catch {
      return; // fail open on wiring error
    }

    // Exit 2 = policy block. Throwing aborts the tool call in opencode.
    if (rc === 2) {
      throw new Error(
        `[openspec-change-gate] Edit to '${filePath}' blocked: the active OpenSpec ` +
          `change must pass 'openspec validate --all' AND carry REVIEWS.md with >=2 ` +
          `'## Reviewer:' sections before code (spec §18). Author + review the change ` +
          `first, or set GSD_SKIP_REVIEWS=1 for a deliberate, logged override.`,
      );
    }
  },
});
