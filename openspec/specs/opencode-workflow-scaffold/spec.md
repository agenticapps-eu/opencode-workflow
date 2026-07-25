# opencode-workflow-scaffold

## Purpose

The capability this repository ships: installing the AgenticApps OpenSpec +
Superpowers (spec v1.0.0) workflow onto the opencode host, and keeping an
installed project current. This is the scaffolder's own product surface,
reconstructed as its first seed capability (§19).

## Requirements

### Requirement: Change-gate enforces review before code

The installed workflow SHALL block a file-mutating edit under an active
OpenSpec change until that change both passes `openspec validate --all` and
carries a `REVIEWS.md` with at least two independent `## Reviewer:` sections.

#### Scenario: Edit blocked before review

- **WHEN** a code edit targets a file under an active change whose `REVIEWS.md`
  has fewer than two reviewers
- **THEN** the change-gate exits non-zero (block)

#### Scenario: Edit allowed after review

- **WHEN** the active change validates green and carries at least two reviewers
- **THEN** the change-gate exits zero (allow)

### Requirement: Bind OpenSpec upstream per host

The scaffolder SHALL generate the OpenSpec slot and `/opsx:*` commands with the
upstream CLI (`openspec init --tools opencode --profile core`) rather than
vendoring a hand-maintained copy.

#### Scenario: Fresh install generates the slot

- **WHEN** `install.sh` runs with the openspec CLI available
- **THEN** an `openspec/` slot and the `/opsx:*` commands are generated
