#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
exec aider --env-file "$ROOT/infra/aider/aider.env" "$@"
