# Agent Contract

## Mandatory: Append-only work log
Write to: docs/AGENT_LOG.md

Rules:
- Only append at the end of the file.
- Never edit, reorder, or delete existing lines.
- Never include secrets (tokens, passwords, private keys) or sensitive customer data.
- Each task must have:
  - timestamp
  - goal + plan
  - key decisions (short)
  - commands run
  - ruff/pytest results

## Mandatory: Command execution
All commands MUST be executed through: ./tools/sbx <command...>

Do not run host commands directly (no pytest/ruff on the host).
EOF


# Agent rules for this repository

## Definition of done
- `make ci` passes (lint + tests)
- `make fmt` applied if formatting changes are needed
- Changes are minimal and scoped to the task

## Preferred commands (use these)
- `make lint`        # ruff check .
- `make fmt`         # ruff format .
- `make fix`         # ruff check . --fix
- `make test-fast`   # quick loop
- `make test`        # full tests
- `make ci`          # lint + full tests

## Safe read-only commands allowed
- `git status`, `git diff`, `git log -n 20`
- `ls`, `find`, `rg` (ripgrep), `cat`, `sed -n`, `python -c` (read-only)
- `pip show <pkg>` (read-only)

## Disallowed (examples)
- destructive filesystem: `rm -rf`, `mv` on repo root, deleting lockfiles
- networked side effects: `git push`, publishing packages
- unpinned installs: `pip install <random>` (unless task explicitly requires)
- editing global configs (~/.ssh, ~/.gitconfig, etc.)

If a new dependency is needed:
- add it to the project’s dependency file and justify it in the PR description.