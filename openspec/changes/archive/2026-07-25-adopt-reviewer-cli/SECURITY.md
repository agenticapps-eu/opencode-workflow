# Security assessment — adopt-reviewer-cli

Scope: the change's trust-boundary surface — `bin/reviewer-cli.sh` (spawns
external vendor CLIs with a caller-supplied prompt) and `install.sh`'s new
`# reviewer-cli-version:` arbitration (reads a marker, writes a shared path).
Method: manual review against the 2-arm baseline this replaces. No secrets,
storage, or network handling is introduced.

**Verdict: no Critical or High findings. The change is net-positive for
security — it adds downgrade-refusal at a shared executable path that previously
had none.**

## Trust boundaries examined

### 1. Prompt → external CLI execution (the wrapper)  — UNCHANGED posture

`reviewer-cli.sh` passes the prompt as a single **argv element**, never through
`eval` or a shell string:

```
run_bounded claude   -p  "$prompt"
run_bounded gemini   -p  "$prompt"
run_bounded opencode run "$prompt"
run_bounded codex    exec "$prompt"
```

- No shell-command injection is reachable from prompt content: the prompt is one
  quoted argument to the vendor binary, which interprets it as an LLM request,
  not a shell command. `run_bounded` forwards `"$@"` without `eval`.
- stdin is pinned to `/dev/null` inside `run_bounded` (one place, both branches),
  which also closes any stdin-borne input channel.
- In the normal flow the prompt is the change's own OpenSpec artifacts
  (self-authored). Even were it attacker-influenced, argv-passing contains it.

This is **identical** to the pre-existing `gemini`/`codex` arms. The two added
arms (`claude`, `opencode run`) are the same argv-passing pattern — two more LLM
subprocesses, each `command -v`-guarded, no new privilege or injection surface.
`opencode` is this host; its producer excludes its own vendor, but even if
invoked the arm is an unprivileged LLM call.

### 2. Marker parsing in the installer  — SAFE

`_reviewer_cli_version_of` reads the marker with a fixed `sed` pattern and uses
the value only in numeric comparison (`_gate_ver_ge`, arithmetic on
`[0-9]`-stripped fields). A hostile or malformed marker cannot inject: the `case`
guard forces any non-`[0-9.]` value to `0.0.0`, and the comparator runs in an
arithmetic context on already-constrained input. Read-only; no `eval`.

### 3. Shared-path write  — IMPROVED

`~/.agenticapps/bin/reviewer-cli.sh` is an executable run by the review producer.
Before this change the installer overwrote it **unconditionally**; now it refuses
to replace a copy carrying a greater-or-equal marker. Writing that path already
requires local write access to the user's home, so the change neither widens nor
narrows who can place a file there — but it removes this host as a source of
silent downgrades, which is a defensive improvement (core #41).

### 4. Secrets  — NONE

Neither the wrapper nor the installer region reads, logs, or transmits secrets.
The prompt is spec text; vendor CLIs use their own credential config, out of
scope for the wrapper.

## Residual / accepted (unchanged from the gate, ADR-0011)

- **A local actor with write access to `~/.agenticapps/bin/` can plant a
  high-marker malicious wrapper the installer will then refuse to overwrite.**
  Accepted: local write to `$HOME` is already full compromise; this is the exact
  posture already accepted for the gate's `# gate-version:` arbitration, and the
  arbitration's purpose (block downgrades) inherently means "trust the
  higher-marked copy." Not introduced by this change.
- **Fleet non-monotonicity**: a co-installed sibling host whose installer lacks
  the same arbitration can still overwrite the shared path. Tracked upstream
  (core #41 fleet dimension); out of scope for this host's installer.

## Conclusion

Ship. The wrapper's execution model is unchanged and injection-safe; the new
installer logic is read-only marker parsing feeding a numeric compare; and the
net effect is a hardening of a shared executable path. No gate on merge.
