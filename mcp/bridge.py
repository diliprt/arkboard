#!/usr/bin/env python3
"""Arkboard MCP stdio bridge.

Forwards JSON-RPC frames from stdin to http://127.0.0.1:7420/mcp.
The Arkboard macOS app must be running. Port 7420 is not negotiable.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

ARKBOARD_URL = "http://127.0.0.1:7420/mcp"


def rpc(method: str, params: dict | None = None, id=1):
    payload = {"jsonrpc": "2.0", "method": method, "id": id}
    if params is not None:
        payload["params"] = params
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        ARKBOARD_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def send(msg: dict):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        method = msg.get("method")
        mid = msg.get("id")
        params = msg.get("params") or {}

        if mid is None:
            continue

        try:
            if method == "initialize":
                send({
                    "jsonrpc": "2.0",
                    "id": mid,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "arkboard-bridge", "version": "2.0.0"},
                    },
                })
            elif method == "tools/list":
                remote = rpc("tools/list", {}, id=mid)
                send({"jsonrpc": "2.0", "id": mid, "result": remote.get("result", {"tools": []})})
            elif method == "tools/call":
                remote = rpc("tools/call", params, id=mid)
                if "error" in remote:
                    send({"jsonrpc": "2.0", "id": mid, "error": remote["error"]})
                else:
                    send({"jsonrpc": "2.0", "id": mid, "result": remote.get("result", {})})
            elif method == "ping":
                send({"jsonrpc": "2.0", "id": mid, "result": {}})
            else:
                send({
                    "jsonrpc": "2.0",
                    "id": mid,
                    "error": {"code": -32601, "message": f"Method not found: {method}"},
                })
        except urllib.error.URLError as e:
            send({
                "jsonrpc": "2.0",
                "id": mid,
                "error": {
                    "code": -32000,
                    "message": f"Arkboard app not reachable at {ARKBOARD_URL}: {e}",
                },
            })
        except Exception as e:
            send({
                "jsonrpc": "2.0",
                "id": mid,
                "error": {"code": -32000, "message": str(e)},
            })


if __name__ == "__main__":
    main()
