#!/usr/bin/env bash
# agenticapps-shared :: migrations/test-fixtures/_example/setup.sh
#
# COPY-ME SKELETON — copy this directory to your consumer repo as a fixture template.
# Convention: test-fixtures/NNNN/MM-name/{setup.sh, verify.sh, expected-exit}
#
# setup.sh: called with the fixture working directory as $1.
# It should apply the migration side-effects (or simulate them) so that verify.sh
# can assert the "applied" state.
#
# Example: create a trivial marker file to prove setup ran.
set -euo pipefail

FIXTURE_DIR="$1"
mkdir -p "$FIXTURE_DIR"
echo "applied" > "$FIXTURE_DIR/marker"
