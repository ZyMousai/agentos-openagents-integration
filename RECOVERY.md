# Recovery Guide

This document describes how to restore the AI Office environment after server failure or accidental deletion.

## 1. Base System

Install:

- Ubuntu
- Docker
- Docker Compose
- Git
- Ollama

## 2. Restore AgentOS

Clone:

    git clone https://github.com/zymousai/agent-platform.git
    cd agent-platform

Restore the .env file from secure backup.

Start:

    docker compose up -d

Verify:

    curl http://127.0.0.1:8000/health

## 3. Restore OpenAgents

Clone:

    git clone https://github.com/ZyMousai/openagents.git
    cd openagents
    git checkout develop

Start the self-hosted workspace.

Run database migrations if required:

    sudo docker compose exec backend alembic upgrade head

## 4. Restore Integration

Clone:

    git clone https://github.com/zymousai/agentos-openagents-integration.git

Start the A2A Gateway:

    cd agentos-openagents-integration/gateway
    sudo docker compose up -d

Verify:

    curl http://127.0.0.1:8200/.well-known/agent.json

## 5. Restore OpenAgents Runtime

Run:

    cd ~/agentos-openagents-integration/runtime
    ./install.sh

Then verify:

    agn runtimes
    agn status

## 6. Verify Ollama

    systemctl is-enabled ollama
    systemctl is-active ollama
    curl http://127.0.0.1:11434/api/tags

## 7. Verify Startup Recovery

Check:

    agn autostart
    loginctl show-user ubuntu -p Linger

Docker containers should use:

    restart: unless-stopped

## 8. Final End-to-End Test

Open Xianniu AI Office and send a message to:

    @platform-builder

Expected path:

    OpenAgents
    -> OpenAgents Node
    -> AgentOS Runtime
    -> A2A Gateway
    -> AgentOS
    -> Ollama
