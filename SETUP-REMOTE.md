# opencode-workflow — local fork & remote setup

This tree was forked from `codex-workflow` with the opencode binding
layer applied. It has **no git history** yet (the fork was a clean tree
copy) and the `vendor/agenticapps-shared` submodule is **not** wired.
Follow the steps below to relocate it, initialize git, attach the
submodule, create the remote, and run it against GLM 5.2 in opencode.

## 1. Relocate next to your other host repos (optional but recommended)

The fork was generated inside your Claude project folder. Move it to sit
beside `codex-workflow`:

```bash
# Note: ~ does NOT expand inside double quotes — use $HOME (which does).
mkdir -p "$HOME/Sourcecode/agenticapps"
mv "$HOME/Documents/Claude/Projects/agentic-workflow/opencode-workflow" \
   "$HOME/Sourcecode/agenticapps-eu/opencode-workflow"
cd ~/Sourcecode/agenticapps-eu/opencode-workflow
```

## 2. Initialize git

```bash
git init -b main
git add -A
git commit -m "chore: fork opencode-workflow from codex-workflow + opencode binding layer"
```

## 3. Wire the shared submodule

`.gitmodules` is present but the gitlink is not — and step 2's
`git add -A` will have committed the plain copy at
`vendor/agenticapps-shared/` as **normal files** in the index. Clear it
from the index first, then attach the real submodule (`--force` accepts
the pre-existing `.gitmodules` entry):

```bash
git rm -r --cached vendor/agenticapps-shared
rm -rf vendor/agenticapps-shared .git/modules/vendor/agenticapps-shared
git submodule add --force https://github.com/agenticapps-eu/agenticapps-shared vendor/agenticapps-shared
git submodule status        # expect one line: <sha> vendor/agenticapps-shared (heads/main)
git commit -m "chore: attach agenticapps-shared submodule"
```

> Tip: to avoid this entirely on a fresh init, exclude the vendored copy
> before the first `git add` (`echo 'vendor/agenticapps-shared/' >> .git/info/exclude`),
> then run the `git submodule add` above.

## 4. Create the remote

With the GitHub CLI:

```bash
gh repo create agenticapps-eu/opencode-workflow --private --source=. --remote=origin --push
```

Or manually — create an empty `agenticapps-eu/opencode-workflow` on
GitHub (no README/license), then:

```bash
git remote add origin git@github.com:agenticapps-eu/opencode-workflow.git
git push -u origin main
```

If you want the repo URL in `.opencode/workflow-config.md` and the
`$schema` lines to match, search-replace any remaining
`github.com/agenticapps-eu/opencode-workflow` references after the repo
exists (they were rewritten from `codex-workflow` automatically).

## 5. Install the skills into opencode

```bash
bash install.sh            # symlinks skills into ~/.config/opencode/skills
# or: OPENCODE_CONFIG_DIR=/custom/path bash install.sh
bash install.sh --dry-run  # preview first
```

opencode auto-discovers `~/.config/opencode/skills/*/SKILL.md` on the
next session.

## 6. Point opencode at GLM 5.2

`opencode.json` (repo root) already declares the provider and default
model. Two auth paths depending on your subscription:

**A. Z.ai GLM Coding Plan (the config as shipped).** Export your key and
go:

```bash
export ZAI_API_KEY="…"     # from z.ai → API keys (Coding Plan)
opencode                   # uses zai-coding-plan/glm-5.2 by default
```

The shipped block uses the OpenAI-compatible endpoint
`https://api.z.ai/api/coding/paas/v4`. If you are on the general API
rather than the Coding Plan, the base URL and available model ids
differ — confirm against your z.ai dashboard.

**B. opencode-hosted subscription ("Go" plan).** If your GLM 5.2 access
comes bundled through opencode's own subscription instead of a direct
z.ai key, authenticate with opencode and select the model from its
provider list rather than the z.ai block:

```bash
opencode auth login        # pick the opencode/zai provider, paste token
```

Then set `"model"` in `opencode.json` to the id opencode lists for GLM
5.2 (e.g. `opencode/glm-5.2` or `zai/glm-5.2` — check `opencode models`).
You can delete the custom `provider.zai-coding-plan` block if you use
this path.

> Verify the model id and base URL with `opencode models` before a long
> run — provider ids and GLM build numbers move quickly.

## 7. Smoke test

```bash
opencode run "set up the workflow"     # should trigger setup-opencode-agenticapps-workflow
bash migrations/check-snapshot-parity.sh   # snapshot drift guard, must PASS
```

## What to verify first (the one behavioral gap)

Codex auto-activates the `agentic-apps-workflow` trigger skill on every
code-touching task. opencode exposes skills but does not guarantee the
same automatic routing. Confirm the trigger fires on a real task; if it
doesn't, add an explicit instruction in `AGENTS.md` (already present)
or a `/`-command, or install a skills-routing plugin. See `docs/LINEAGE.md`.
