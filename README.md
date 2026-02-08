# local-agent
A repo to hold a setup for a local coding agent to perform tasks while I'm away from the pc.


# local
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