# local-agent
A repo to hold a setup for a local coding agent to perform tasks while I'm away from the pc.

# local - repo
```bash

mkdir -p docs tools docker/sandbox worktrees


cat > AGENTS.md <<'EOF'
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


cat > docs/AGENT_LOG.md <<'EOF'
# Agent Work Log (append-only)

This file is append-only. Never edit or delete existing lines.

## Entry template (append below; do not modify past entries)

### YYYY-MM-DDTHH:MM:SS+02:00 — Task: <short title>
- Context:
- Goal:
- Plan:
- Key decisions / rationale:
- Commands run:
  - <command 1>
  - <command 2>
- Changes made:
  - <files/modules touched>
- Tests:
  - ruff: <pass/fail + command>
  - pytest: <pass/fail + command>
- Result:
- Follow-ups / risks:
EOF


cat > tools/check_append_only.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="docs/AGENT_LOG.md"

# If not staged, nothing to check
git diff --cached --name-only | grep -qx "$LOG_FILE" || exit 0

# numstat: added<TAB>deleted<TAB>file
read -r added deleted file < <(git diff --cached --numstat -- "$LOG_FILE")

deleted=${deleted:-0}

if [[ "$deleted" != "0" && "$deleted" != "-" ]]; then
  echo "ERROR: $LOG_FILE is append-only. Detected deletions/edits (deleted=$deleted)."
  echo "Only append to the end; do not edit or remove past lines."
  exit 1
fi
EOF

chmod +x tools/check_append_only.sh


cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: local
    hooks:
      - id: agent-log-append-only
        name: Enforce append-only docs/AGENT_LOG.md
        entry: tools/check_append_only.sh
        language: system
        pass_filenames: false
EOF


python3 -m pip install --user pre-commit
pre-commit install
pre-commit run --all-files
```

## local - extedned agent
```bash
5) Isolate command execution in a locked-down container
Threat model & design

The agent driver (OpenHands/Aider/your runner) can run on the host, but it must not run arbitrary host shell commands.

All builds/tests happen inside a sandbox container with:

non-root user

cap_drop: ALL

no-new-privileges

optional network: none (recommended for executing untrusted code)

5.1 Create sandbox image: docker/sandbox/Dockerfile
cat > docker/sandbox/Dockerfile <<'EOF'
FROM python:3.12-slim

# Minimal OS tools you typically need for Python builds/tests in monorepos
RUN apt-get update && apt-get install -y --no-install-recommends \
    git bash build-essential \
  && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -u 1000 agent
USER agent

WORKDIR /workspace

# Keep pip/venv in mounted volumes (configured in docker-compose)
ENV PIP_CACHE_DIR=/home/agent/.cache/pip
EOF

5.2 Create docker-compose.yml

This defines two services:

sandbox_net (network enabled) for initial dependency install/bootstrap if needed

sandbox (network disabled) for executing agent-run code safely

cat > docker-compose.yml <<'EOF'
services:
  sandbox_net:
    build:
      context: .
      dockerfile: docker/sandbox/Dockerfile
    working_dir: /workspace
    volumes:
      - ./worktrees/current:/workspace:rw
      - sbx_venv:/opt/venv
      - sbx_pip_cache:/home/agent/.cache/pip
    environment:
      - VIRTUAL_ENV=/opt/venv
      - PATH=/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    pids_limit: 512

  sandbox:
    extends:
      service: sandbox_net
    network_mode: "none"
    read_only: true
    tmpfs:
      - /tmp
EOF

5.3 Create the sandbox command wrapper the agent must use: tools/sbx

This wrapper:

ensures you’re operating on a worktree (worktrees/current)

ensures a persistent venv in a docker volume

runs your command inside sandbox (network off by default)

allows a separate --net mode for bootstrapping dependencies

cat > tools/sbx <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

MODE="sandbox"        # default: network disabled
if [[ "${1:-}" == "--net" ]]; then
  MODE="sandbox_net"  # network enabled
  shift
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: ./tools/sbx [--net] <command...>"
  exit 2
fi

# Ensure worktree mount exists
mkdir -p worktrees/current

# Run inside the sandbox container
docker compose run --rm "$MODE" bash -lc '
  set -euo pipefail
  if [[ ! -x /opt/venv/bin/python ]]; then
    python -m venv /opt/venv
  fi
  . /opt/venv/bin/activate
  python -m pip install -U pip >/dev/null

  # Project install: adjust to your monorepo conventions.
  # Option A: editable install of root package (if applicable)
  python -m pip install -e . >/dev/null 2>&1 || true

  # Always ensure tools exist (you can also pin versions in pyproject/requirements)
  python -m pip install -U ruff pytest >/dev/null

  exec "$@"
' -- "$@"
EOF

chmod +x tools/sbx


How you use it day-to-day:

# First time / when deps change (needs network)
./tools/sbx --net make lint
./tools/sbx --net make test-fast

# Normal “safe execution” mode (no network)
./tools/sbx make lint
./tools/sbx make test-fast
./tools/sbx make ci

6) Reduce blast radius further with git worktrees (recommended for agents)

Instead of letting an agent work directly on your main checkout, create a worktree per task:

# From repo root
TASK=task-123
git worktree add -b "agent/$TASK" "worktrees/$TASK" HEAD

# Point "current" at that worktree (what the container mounts)
rm -rf worktrees/current
ln -s "$TASK" worktrees/current


If the agent goes wild, you can delete the whole worktree safely:

git worktree remove "worktrees/$TASK"
git branch -D "agent/$TASK"
```


# local - vllm
```bash
 docker compose --env-file infra/vllm/.env -f infra/vllm/docker-compose.yaml up -d
 docker compose --env-file infra/vllm/.env -f infra/vllm/docker-compose.yaml down
 docker logs -f vllm-qwen25-coder-32b-awq

 docker exec -it vllm-qwen25-coder-32b-awq bash -lc "python3 - <<'PY'
import socket
s=socket.socket(); s.settimeout(1)
try:
    s.connect(('127.0.0.1',8000))
    print('LISTENING')
except Exception as e:
    print('NOT LISTENING:', e)
finally:
    s.close()
PY"

docker exec -it vllm-qwen25-coder-32b-awq bash -lc   "curl -s http://127.0.0.1:8000/v1/models -H 'Authorization: Bearer token-local-dev' | head"
```

# local - aider
```bash
python -m venv ~/venvs/aider
source ~/venvs/aider/bin/activate
python -m pip install -U pip
python -m pip install aider-install
aider-install

#
# warning: `/home/ubuntu/.local/bin` is not on your PATH. To use installed tools, run `export PATH="/home/ubuntu/.local/bin:$PATH"` or `uv tool update-shell`.

```

# local - continue
```
C1) Install Continue in VS Code

Open VS Code

Extensions → search “Continue” → Install (publisher: Continue)

(Continue is the VS Code extension; after install you’ll get a “Continue” panel/sidebar.)

C2) Configure Continue to use your local vLLM (OpenAI provider)

Continue uses an “OpenAI” provider configuration where you can override the base URL to any OpenAI-compatible server (like vLLM).

Option A (recommended): Put config in Continue’s config file

Open Continue settings → Open Config (Continue sidebar → ⚙️).
Edit config.yaml to include something like this:

name: Local vLLM (Qwen2.5 Coder)
version: 1.0.0
schema: v1

models:
  - name: Qwen2.5 Coder 32B (local vLLM)
    provider: openai
    model: qwen2.5-coder-32b-awq
    apiBase: http://localhost:8000/v1
    apiKey: token-local-dev
    roles:
      - chat
      - edit
      - apply
      - autocomplete


Notes

apiBase (or baseUrl in some Continue versions/docs) must point to your vLLM OpenAI endpoint.

model must match your served model name from vLLM: --served-model-name qwen2.5-coder-32b-awq.
```

# local - openhands

## install
```bash
# install uv (follow uv's install guide if you don't already have it)
# then:
uv tool install openhands --python 3.12
```


## configure repo to work on
```bash
# example
cd ~/repos/<your-target-repo>

# in our case
cd ~/repos/gkrp_data_portal

# check the status, commit changes, etc. as needed
git status

# create a dedicated branch + worktree for the agent
TASK=agent/$(date +%Y%m%d-%H%M)

# create a separate folder and worktree
git worktree add -b "$TASK" ~/tmp/gkrp_data_portal "$TASK" 2>/dev/null || git worktree add -b "$TASK" ~/tmp/gkrp_data_portal HEAD
```

## Add OpenHands repo rules inside the worktree 
```bash
cd ~/tmp/gkrp_data_portal/



```

```bash
export LLM_MODEL="openai/qwen2.5-coder-32b-awq"
export LLM_API_KEY="token-local-dev"
export LLM_BASE_URL="http://host.docker.internal:8000/v1"

# optional safety: require confirmation for actions
export SECURITY_CONFIRMATION_MODE=true

openhands --override-with-envs serve --mount-cwd
```