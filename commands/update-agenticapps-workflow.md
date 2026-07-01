---
description: Apply pending AgenticApps workflow migrations to an already-installed project
agent: build
---
Use the `update-opencode-agenticapps-workflow` skill to bring this project's
AgenticApps workflow up to date.

Read `.opencode/workflow-version.txt`, compute the pending migrations (those
whose `from_version >` the installed version), and apply only those in order
per the skill. This is the migration path — unlike setup, it does not lay down
the full snapshot. Show the dry-run diffs first, then apply and commit.

$ARGUMENTS
