#!/usr/bin/env python3
"""Emit one JSON line with herdr agent counts and Claude rate limits."""
import json
import os
import subprocess
import time

LIMITS_CACHE = os.path.expanduser("~/.cache/claude-bar/limits.json")
STALE_AFTER = 15 * 60
HERDR = os.path.expanduser("~/.local/bin/herdr")


def agents():
    try:
        out = subprocess.run(
            [HERDR, "agent", "list"], check=False, capture_output=True, text=True, timeout=3
        )
        listed = json.loads(out.stdout)["result"]["agents"]
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
        return None
    counts = {"working": 0, "blocked": 0, "idle": 0, "list": []}
    for agent in listed:
        status = agent.get("agent_status")
        if status in counts:
            counts[status] += 1
        counts["list"].append({
            "status": status,
            "cwd": agent.get("cwd") or "",
            "terminal_id": agent.get("terminal_id"),
            "focused": agent.get("focused", False),
        })
    order = {"blocked": 0, "working": 1}
    counts["list"].sort(key=lambda a: (order.get(a["status"], 2), a["cwd"]))
    return counts


def window(rate_limits, key):
    entry = rate_limits.get(key) or {}
    if entry.get("used_percentage") is None:
        return None
    return {"pct": entry["used_percentage"], "resets_at": entry.get("resets_at")}


def limits():
    try:
        with open(LIMITS_CACHE) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        return {"five_hour": None, "seven_day": None, "stale": True}
    rate_limits = cache.get("rate_limits") or {}
    now = time.time()
    five = window(rate_limits, "five_hour")
    seven = window(rate_limits, "seven_day")
    for w in (five, seven):
        if w and w["resets_at"] and w["resets_at"] < now:
            w["pct"] = 0
            w["resets_at"] = None
    return {
        "five_hour": five,
        "seven_day": seven,
        "stale": now - cache.get("updated_at", 0) > STALE_AFTER,
    }


print(json.dumps({"agents": agents(), **limits()}))
