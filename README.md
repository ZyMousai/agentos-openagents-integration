# AgentOS OpenAgents Integration

Integration layer between OpenAgents and AgentOS for the internal AI Office.

## Architecture

OpenAgents
    ↓
Custom AgentOS Runtime
    ↓
A2A Gateway :8200
    ↓
AgentOS :8000
    ↓
Ollama :11434

## Repository Structure

gateway/
- app.py
- Dockerfile
- docker-compose.yml
- requirements.txt

runtime/
- agentos.js
- install.sh
- index.js.current
- registry.json.current
- registry.json.original

## Current Deployment

Server path:

~/agentos-openagents-integration

Related projects:

- ~/agent-platform
- ~/openagents

Current Agent:

- platform-builder

## Gateway

The gateway converts OpenAgents A2A requests into AgentOS A2A requests.

Current local endpoint:

http://127.0.0.1:8200

AgentOS endpoint:

http://127.0.0.1:8000

## OpenAgents Runtime

The custom `agentos` runtime allows OpenAgents Node to launch and communicate with AgentOS agents.

The installed OpenAgents launcher may overwrite custom runtime changes after an update.

Use:

runtime/install.sh

to restore the AgentOS runtime integration.

## Security

Never commit:

- .env files
- Workspace tokens
- API keys
- passwords
- private keys
- pairing codes

## Related Repositories

### agent-platform

AgentOS application platform.

Repository:

zymousai/agent-platform

### openagents

Fork of OpenAgents used for self-hosted deployment.

Repository:

ZyMousai/openagents

## Status

Current end-to-end path is working:

OpenAgents Workspace
→ Ubuntu OpenAgents Node
→ AgentOS Runtime
→ A2A Gateway
→ AgentOS
→ Ollama
→ RTX 5090

Tested with:

platform-builder
