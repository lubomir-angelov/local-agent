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
