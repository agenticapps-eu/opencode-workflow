<!-- BEGIN: opencode-workflow global section (do not remove this marker) -->

## AgenticApps Workflow (Global)

All AgenticApps EU repos installed against `opencode-workflow` use the
spec-first workflow with the `agentic-apps-workflow` trigger skill.

The trigger skill auto-activates on any code-touching task. It emits
the commitment-ritual block (per `agenticapps-workflow-core` spec/01)
and routes to the right `opencode-*` gate skills based on task size and
gate triggers.

Setup a project: `$setup-opencode-agenticapps-workflow`.
Update an existing project: `$update-opencode-agenticapps-workflow`.

The opencode-workflow scaffolder repo:
[github.com/agenticapps-eu/opencode-workflow](https://github.com/agenticapps-eu/opencode-workflow).

<!-- END: opencode-workflow global section -->
