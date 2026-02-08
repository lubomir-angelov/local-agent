# local-agent
A repo to hold a setup for a local coding agent to perform tasks while I'm away from the pc.


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