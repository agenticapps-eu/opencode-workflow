## Reindexing

Always reindex with `npx gitnexus analyze --skip-agents-md`, never bare — despite
what the generated block above says. A bare `analyze` rewrites the managed region
in this file *and* re-injects the one deliberately removed from `AGENTS.md`. The
counts above are frozen on purpose and will drift; that is the intended trade.
