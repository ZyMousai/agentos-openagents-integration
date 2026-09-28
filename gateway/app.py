import os

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI()

AGENTOS_URL = os.getenv("AGENTOS_URL", "http://127.0.0.1:8000")
AGENT_ID = os.getenv("AGENT_ID", "platform-builder")

BASE = f"{AGENTOS_URL}/a2a/agents/{AGENT_ID}"


@app.get("/.well-known/agent.json")
async def agent_card():
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{BASE}/.well-known/agent-card.json")
        r.raise_for_status()
        card = r.json()

    # OpenAgents 后续会 POST 到这个 Adapter 根路径
    card["url"] = "/"

    return JSONResponse(card)


@app.post("/")
async def jsonrpc(request: Request):
    body = await request.json()

    method = body.get("method")

    routes = {
        "message/send": "message:send",
        "tasks/get": "tasks:get",
        "tasks/cancel": "tasks:cancel",
    }

    endpoint = routes.get(method)

    if not endpoint:
        return JSONResponse(
            {
                "jsonrpc": "2.0",
                "id": body.get("id"),
                "error": {
                    "code": -32601,
                    "message": f"Method not supported: {method}",
                },
            }
        )

    payload = {
        "id": body.get("id"),
        "params": body.get("params") or {},
    }

    async with httpx.AsyncClient(timeout=300) as client:
        r = await client.post(
            f"{BASE}/v1/{endpoint}",
            json=payload,
        )

    return JSONResponse(
        content=r.json(),
        status_code=r.status_code,
    )
