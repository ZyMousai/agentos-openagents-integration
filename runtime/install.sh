#!/bin/bash
set -euo pipefail

RUNTIME_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER="$HOME/.openagents/nodejs/node_modules/@openagents-org/agent-launcher"

echo "== OpenAgents AgentOS Runtime Installer =="

if [ ! -d "$LAUNCHER" ]; then
    echo "ERROR: OpenAgents launcher not found:"
    echo "$LAUNCHER"
    exit 1
fi

if [ ! -f "$RUNTIME_DIR/agentos.js" ]; then
    echo "ERROR: $RUNTIME_DIR/agentos.js not found"
    exit 1
fi

# Backup current official files
BACKUP="$RUNTIME_DIR/backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

cp "$LAUNCHER/src/adapters/index.js" "$BACKUP/index.js"
cp "$LAUNCHER/registry.json" "$BACKUP/registry.json"

echo "Backup: $BACKUP"

# Install AgentOS adapter
cp "$RUNTIME_DIR/agentos.js" \
   "$LAUNCHER/src/adapters/agentos.js"

# Patch adapters/index.js idempotently
python3 - "$LAUNCHER/src/adapters/index.js" <<'PY'
import sys

path = sys.argv[1]

with open(path) as f:
    s = f.read()

require_line = "const AgentOSAdapter = require('./agentos');"

if require_line not in s:
    marker = "const OpenWorkerAdapter = require('./openworker');"

    if marker not in s:
        raise SystemExit(
            "ERROR: OpenWorkerAdapter marker not found. "
            "Launcher structure may have changed."
        )

    s = s.replace(
        marker,
        marker + "\n" + require_line
    )

if "agentos: AgentOSAdapter," not in s:
    marker = "openworker: OpenWorkerAdapter,"

    if marker not in s:
        raise SystemExit(
            "ERROR: openworker adapter registry marker not found."
        )

    s = s.replace(
        marker,
        marker + "\n  agentos: AgentOSAdapter,"
    )

with open(path, "w") as f:
    f.write(s)

print("Adapter index patched")
PY

# Patch registry.json idempotently
python3 - "$LAUNCHER/registry.json" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path) as f:
    data = json.load(f)

data = [
    x for x in data
    if x.get("name") != "agentos"
]

agentos = {
    "name": "agentos",
    "label": "AgentOS",
    "description": "External AgentOS agent via A2A",
    "tags": ["agent", "a2a", "agentos"],
    "featured": True,
    "order": 10,
    "builtin": True,

    "support": {
        "install": True,
        "workspace": True,
        "collaboration": True
    },

    "install": {
        "api_only": True
    },

    "adapter": {
        "module": "openagents.adapters.agentos",
        "class": "AgentOSAdapter"
    },

    "env_config": [
        {
            "name": "AGENTOS_A2A_URL",
            "label": "AgentOS A2A URL",
            "type": "text",
            "required": False,
            "default": "http://127.0.0.1:8200"
        }
    ],

    "workspace_model": False,
    "vendor": "AgentOS",
    "tagline": "Connect an AgentOS agent through A2A.",
    "protocol": "a2a"
}

data.append(agentos)

with open(path, "w") as f:
    json.dump(data, f, indent=2)

print("Registry patched")
PY

# Validate
python3 -m json.tool "$LAUNCHER/registry.json" >/dev/null

node -e "
const a=require('$LAUNCHER/src/adapters');

if (!a.ADAPTER_MAP || !a.ADAPTER_MAP.agentos) {
  console.error('AgentOS adapter not registered');
  process.exit(1);
}

console.log('AgentOS adapter load OK');
"
echo
echo "AgentOS runtime patch installed successfully."
echo "Restarting OpenAgents daemon..."

agn down || true
agn up

echo
agn status
