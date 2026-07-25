## 1. RED baseline first (harness before replacement)

- [ ] 1.1 Vendor core `tools/change-gate-conformance.sh` → `tools/change-gate-conformance.sh` (chmod +x)
- [ ] 1.2 Run the harness against the CURRENT gate and record the RED baseline (16/28) in the commit body — before the gate is touched

## 2. Vendor gate logic from core (byte-for-byte)

- [ ] 2.1 Copy core `reference-implementations/openspec-change-gate/openspec-change-gate.sh` → `bin/openspec-change-gate.sh`; confirm `# gate-version: 1.2.0` marker and byte-parity with the pinned core revision `ae90483`
- [ ] 2.2 GREEN: `tools/change-gate-conformance.sh bin/openspec-change-gate.sh` → 28/28, no FAIL rows

## 3. Host-local wiring (env injection outside the byte-identical files)

- [ ] 3.1 RED first: add the failing self-review propagation check for the two invocation points wired in THIS section — a `## Reviewer: opencode` self-review MUST NOT satisfy the threshold through the plugin and the installed pre-commit (CI is verified in 4.3, once the workflow exists)
- [ ] 3.2 `bin/git-hooks/pre-commit`: adopt core's resolution logic; export `OPENSPEC_GATE_SELF=opencode` before dispatch (do NOT edit the vendored `.sh`)
- [ ] 3.3 `bin/openspec-change-gate.ts`: pass `OPENSPEC_GATE_SELF=opencode` in the plugin spawn env; re-run 3.1 → green (plugin + pre-commit)

## 4. CI enforcement floor

- [ ] 4.1 Add `.github/workflows/openspec-gate.yml` from core's workflow, adjusted to this repo's paths, with `OPENSPEC_GATE_SELF=opencode` in the job env (harness-proves-gate step, then `--ci`)
- [ ] 4.2 Add `tools/change-gate-conformance.sh` to `ci.yml`'s shell-syntax-check list
- [ ] 4.3 Verify CI-slice self-review propagation: with the workflow's job env, a `## Reviewer: opencode` self-review does NOT satisfy `--ci` (the CI portion deferred from 3.1, now that the workflow exists)

## 5. Installer downgrade-refusal (this host's part of #15)

- [ ] 5.1 RED first: write the failing version-arbitration cases — installed `>=` incoming → keep; installed `<` incoming → replace; installed unmarked → replace; equal → no-op; malformed incoming marker → treated as `0.0.0`, never crashes
- [ ] 5.2 Implement in `install.sh`: before writing the shared `~/.agenticapps/bin/openspec-change-gate.sh`, read both `# gate-version:` markers, apply the comparator, print what it did; re-run 5.1 → green
- [ ] 5.3 Verify `install.sh` `bash -n` clean and `--dry-run` shows the arbitration path

## 6. Verification & lockstep

- [ ] 6.1 `migrations/run-tests.sh` §18 truth-table suite passes against the vendored gate
- [ ] 6.2 `migrations/check-snapshot-parity.sh` PASS (regenerate snapshot if the gate is part of it)
- [ ] 6.3 Confirm the `opencode-openspec-change-review` producer's `## Reviewer:` format is still counted by core's reviewer counter. If incompatible, STOP and amend this change's artifacts (proposal/design/spec) before touching the producer — do not expand implementation scope ad hoc

## 7. Lifecycle close-out

- [ ] 7.1 ADR recording the re-vendor decision and the scoped (this-installer) downgrade guarantee (`docs/decisions/NNNN-revendor-change-gate.md`)
- [ ] 7.2 Independent Stage-2 code review (`superpowers:requesting-code-review`)
- [ ] 7.3 `/cso` on the gate change → SECURITY.md
- [ ] 7.4 Archive the change; open the adoption PR referencing core #33/#34 and issue #15 with the harness score
