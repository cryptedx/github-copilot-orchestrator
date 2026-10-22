#!/usr/bin/env python3
"""Zeigt, mit welchem Modell jeder Subagent einer Copilot-Session lief.

Aufruf: python3 tools/check-session.py [Session-ID | Pfad zu events.jsonl]
Ohne Argument nimmt das Skript die zuletzt geänderte Session.
Exit-Code 1, wenn ein Subagent mit einem anderen Modell lief als in seiner Agent-Datei.
"""
import json
import os
import re
import sys
from pathlib import Path

AGENT_KEYS = ["agentname", "customagentname", "subagentname", "agenttype", "agent_type",
              "subagenttype", "subagent_type", "agent", "name"]
MODEL_KEYS = ["resolvedmodel", "subagentmodel", "model"]
SOURCE_KEYS = ["modelselectionsource", "taskmodelsource"]
EFFORT_KEYS = ["reasoningeffort", "reasoning_effort", "effort"]
CONTEXT_KEYS = ["contexttier", "context_tier"]
DISPATCH_TOOLS = {"task", "agent", "custom-agent", "custom_agent", "runsubagent"}


def copilot_home():
    return Path(os.environ.get("COPILOT_HOME") or Path.home() / ".copilot")


def find_events(arg):
    if arg:
        p = Path(arg)
        if p.is_file():
            return p
        if p.is_dir():
            return p / "events.jsonl"
        return copilot_home() / "session-state" / arg / "events.jsonl"
    sessions = [d for d in (copilot_home() / "session-state").iterdir() if (d / "events.jsonl").is_file()]
    if not sessions:
        sys.exit("Keine Session mit events.jsonl gefunden.")
    return max(sessions, key=lambda d: (d / "events.jsonl").stat().st_mtime) / "events.jsonl"


def expected_models():
    """model: aus den Agent-Dateien, zuerst installiert, dann aus dem Repo."""
    models = {}
    dirs = [Path(os.environ.get("COPILOT_AGENTS_DIR") or copilot_home() / "agents"),
            Path(__file__).resolve().parent.parent / "agents"]
    for d in dirs:
        for f in sorted(d.glob("*.agent.md")) if d.is_dir() else []:
            text = f.read_text(encoding="utf-8-sig")
            name = re.search(r"^name:\s*(\S+)", text, re.M)
            model = re.search(r"^model:\s*(\S+)", text, re.M)
            if name and model:
                models.setdefault(name.group(1).strip("'\""), model.group(1).strip("'\""))
    return models


def flatten(obj, out=None):
    """Alle Blattwerte nach kleingeschriebenem Schlüssel, erster Treffer gewinnt."""
    out = {} if out is None else out
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, (dict, list)):
                flatten(v, out)
            elif isinstance(k, str):
                out.setdefault(k.lower(), v)
    elif isinstance(obj, list):
        for v in obj:
            flatten(v, out)
    return out


def pick(flat, keys):
    for k in keys:
        if flat.get(k) not in (None, ""):
            return str(flat[k])
    return ""


def load(path):
    events = []
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            try:
                events.append(json.loads(line))
            except ValueError:
                pass
    return events


def rows_from(events):
    started = [e for e in events if re.search(r"subagent.*start", str(e.get("type", "")), re.I)]
    kind = "subagent.started"
    if not started:
        # Ersatz: die Aufrufe des Werkzeugs, das Subagenten startet
        started = [e for e in events if e.get("type") == "tool.execution_start"
                   and str(flatten(e.get("data", {})).get("toolname", "")).lower() in DISPATCH_TOOLS]
        kind = "Werkzeugaufruf"
    rows = []
    for e in started:
        flat = flatten(e.get("data", {}))
        rows.append({
            "zeit": str(e.get("timestamp", ""))[11:19],
            "agent": pick(flat, AGENT_KEYS),
            "modell": pick(flat, MODEL_KEYS),
            "quelle": "/".join(v for v in (pick(flat, [k]) for k in SOURCE_KEYS) if v),
            "reasoning": pick(flat, EFFORT_KEYS),
            "kontext": pick(flat, CONTEXT_KEYS),
        })
    return kind, rows


def main():
    path = find_events(sys.argv[1] if len(sys.argv) > 1 else None)
    if not path.is_file():
        sys.exit(f"Nicht gefunden: {path}")
    expected = expected_models()
    kind, rows = rows_from(load(path))
    print(f"Session: {path.parent.name}  ({len(rows)} × {kind})")
    if not rows:
        print("Keine Subagenten gestartet.")
        return 0
    head = ["Zeit", "Agent", "Modell", "Erwartet", "Quelle", "Reasoning", "Kontext", "Status"]
    table, mismatches = [], 0
    for r in rows:
        want = expected.get(r["agent"], "")
        if not want or not r["modell"]:
            status = "?"
        elif r["modell"] == want:
            status = "ok"
        else:
            status = "ABWEICHUNG"
            mismatches += 1
        table.append([r["zeit"], r["agent"] or "?", r["modell"] or "?", want or "–",
                      r["quelle"], r["reasoning"], r["kontext"], status])
    widths = [max(len(str(x)) for x in col) for col in zip(head, *table)]
    for line in [head] + table:
        print("  ".join(str(x).ljust(w) for x, w in zip(line, widths)).rstrip())
    if mismatches:
        print(f"\n{mismatches} Subagent-Start(s) mit anderem Modell als in der Agent-Datei.")
    if any(r[1] == "?" for r in table):
        print("Hinweis: Agent-Name nicht erkannt. Bitte eine Zeile aus events.jsonl ins Issue kopieren.")
    return 1 if mismatches else 0


if __name__ == "__main__":
    sys.exit(main())
