---
description: Install the AgenticApps spec-first workflow into this project (snapshot install, no migration replay)
agent: build
---
Use the `setup-opencode-agenticapps-workflow` skill to bootstrap this project
with the AgenticApps workflow.

Follow the skill's stages exactly: pre-flight (git repo, not already installed,
scaffolder + snapshot present, resolve LATEST from VERSION), gather project
details for placeholder substitution, lay down the latest snapshot
(`.opencode/workflow-config.md`, `.planning/config.json`, the AGENTS.md
workflow block, `docs/decisions/`, and stamp `.opencode/workflow-version.txt`),
run the post-checks, and make the single atomic install commit. Do NOT replay
the migration chain — this is a snapshot install.

$ARGUMENTS
