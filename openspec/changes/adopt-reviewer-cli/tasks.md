## 1. RED baseline first (harness before replacement)

- [ ] 1.1 Vendor core `tools/reviewer-cli-conformance.sh` → `tools/reviewer-cli-conformance.sh` (chmod +x); confirm sha256 `4e45150a…9f6656` byte-parity with core `60cd83f`
- [ ] 1.2 Run the harness against the CURRENT wrapper and record the RED baseline (missing `claude`/`opencode` arms, no version marker) in the commit body — before `bin/reviewer-cli.sh` is touched

## 2. Vendor wrapper logic from core (byte-for-byte)

- [ ] 2.1 Copy core `reference-implementations/reviewer-cli/reviewer-cli.sh` → `bin/reviewer-cli.sh`; confirm `# reviewer-cli-version: 1.0.0` marker and sha256 `32718bb9…4b7ec6` byte-parity with the pinned core revision `60cd83f`
- [ ] 2.2 GREEN: `tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh` → every section passes, no FAIL rows

## 3. Installer downgrade-refusal (this host's part of core #41)

- [ ] 3.1 RED first: write failing version-arbitration cases for the reviewer-cli marker — **destination absent → install unconditionally**; installed `>=` incoming → keep; installed `<` incoming → replace; installed unmarked (no marker) → parsed `0.0.0` → replace; installed with **no leading numeric run** (e.g. `# reviewer-cli-version: abc`) → parsed `0.0.0` → replace; a **partial-prefix marker** (e.g. `1.x`) is compared as `1.0.0`, NOT `0.0.0` — matching the gate's shipped extractor; equal → no-op; malformed incoming marker never crashes the installer
- [ ] 3.2 Implement in `install.sh`: add a `# reviewer-cli-version:` arbitration region (parallel to `gate-version-arbitration`) with `_reviewer_cli_version_of` + `_reviewer_cli_should_install` **reusing the existing `_gate_ver_ge` comparator**; convert the unconditional `install … reviewer-cli.sh` line to the guarded form that prints what it did; re-run 3.1 → green
- [ ] 3.3 Verify `install.sh` `bash -n` clean and `--dry-run` shows the reviewer-cli arbitration path

## 4. CI enforcement

- [ ] 4.1 Add a "Prove the reviewer-cli is conformant" step to `.github/workflows/openspec-gate.yml` running `tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh`, sibling to the existing gate-conformance step
- [ ] 4.2 Add `tools/reviewer-cli-conformance.sh` to `ci.yml`'s shell-syntax-check list

## 5. Documentation sync (keep vendored artifact and its consumer in step)

- [ ] 5.1 Correct the `opencode-openspec-change-review` producer skill's stale `REVIEWER_TIMEOUT` default (`180s` → `300s`, both mentions) to match the vendored 1.0.0 wrapper. No vendor-selection change (still `gemini` + `codex`)

## 6. Verification & lockstep

- [ ] 6.1 `migrations/run-tests.sh` passes (the enforcement-artifacts test still finds an executable `bin/reviewer-cli.sh`)
- [ ] 6.2 `migrations/check-snapshot-parity.sh` PASS (the snapshot carries neither `bin/` nor `tools/`, so it must remain untouched — confirm)
- [ ] 6.3 Confirm the producer's `## Reviewer:` format and `gemini`+`codex` selection are unaffected by the wrapper swap; both arms still dispatch through the vendored wrapper

## 7. Lifecycle close-out

- [ ] 7.1 ADR-0012 recording the adoption and the scoped (this-installer) downgrade guarantee; note it supersedes ADR-0011's classification of `bin/reviewer-cli.sh` as host-local wiring; add it to `docs/decisions/README.md` index
- [ ] 7.2 Independent **Stage-3** code review (`superpowers:requesting-code-review`) against the implementation diff — distinct from the Stage-2 pre-code change review already produced in REVIEWS.md
- [ ] 7.3 `/cso` on the change → SECURITY.md. The wrapper spawns external CLIs with a caller-supplied prompt AND adds two executable dispatch arms (`claude`, `opencode`) at a fleet-shared path; the audit must **assess** the trust-boundary delta from the 2-arm copy, not assume it is unchanged
- [ ] 7.4 Archive the change; open the adoption PR referencing core #41/#42 and the harness score
