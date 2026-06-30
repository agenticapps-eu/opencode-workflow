#!/usr/bin/env bash
# agenticapps-shared :: migrations/test-fixtures/_example/verify.sh
#
# COPY-ME SKELETON — idempotency check for the _example fixture.
# Convention: exits 0 if the migration was "applied" (skip — already done),
# non-zero if "not-applied" (please apply).
#
# $1 = fixture working directory (same dir passed to setup.sh)
set -euo pipefail

FIXTURE_DIR="$1"
[ -f "$FIXTURE_DIR/marker" ]
