# Session-Protokoll: Entstehung des Agent-Sets

Datum: 19. Oktober 2026

## Ausgangslage

- Bei der Arbeit ist nur GitHub Copilot erlaubt (Copilot App, vorher Copilot CLI). Das Budget liegt bei rund 300 $ im Monat.
- Zur Auswahl stehen Opus 5.5, Sonnet 5.5, Haiku 5.5, GPT-6 Luna und GPT-6.1 Sol.
- Die Leistung entspricht ungefähr: Sol ≈ Sonnet, Luna ≈ Haiku. Luna ist sehr günstig.
- Gesucht war eine allgemein nutzbare Lösung: Die großen Modelle orchestrieren, die kleinen arbeiten. Das soll auch zusammen mit Skills funktionieren, zum Beispiel mit denen von Matt Pocock.

## Entscheidungen

1. **Custom Agent statt Prompt-Befehl.** Ein Orchestrator-Agent ist dauerhaft aktiv. So muss man nicht zwei Skills gleichzeitig starten: Der Agent liefert die Orchestrierung, der Skill die Aufgabe.
2. **Der Skill bestimmt den Ablauf, der Orchestrator nur das Wer.** Planen, Entscheiden und Rückfragen bleiben bei Opus. Lesen, Schreiben, Ausführen und Prüfen werden delegiert.
3. **Subagenten erben keine Skills.** Deshalb gibt der Orchestrator ihnen die nötigen Skill-Regeln im Auftrag mit.
4. **Zwei Modellfamilien zur Kreuzprüfung.** Umsetzer und Prüfer gehören jeweils zu verschiedenen Familien. Die Scouts bestätigen kritische Aussagen gegenseitig, und Luna hinterfragt als `challenger` die Pläne.
5. **Luna bekommt mehr Arbeit.** Luna übernimmt den `runner` (Tests, Builds, Linter) sowie die Rollen `challenger` und `scout-luna`.
6. **Modell-IDs statt Anzeigenamen** im Frontmatter, zum Beispiel `gpt-6-luna`.
7. **Ultra-Modus als eigener Agent.** `orchestrator-ultra` überträgt die Muster des Ultracode-Modus der Claude App (gegnerische Prüfung, Judge Panel, Weitersuchen bis nichts mehr kommt, Completeness Critic) auf die vorhandenen Rollen. Er ist ein eigener Agent und kein Schalter, damit der normale Orchestrator günstig bleibt. Die gegnerische Prüfung läuft standardmäßig mit `scout`, `scout-luna` und `challenger`. Ein Reviewer prüft nur Befunde, die eine Code-Änderung auslösen. Damit sinkt ein Ultra-Lauf geschätzt von $6–20 auf $4–10.

## Offene Punkte

- Die abgeleiteten Modell-IDs (`claude-opus-5.5`, `claude-sonnet-5.5`, `claude-haiku-5.5`, `gpt-6.1-sol`) sind gegen die GitHub-Doku geprüft (alle Modelle gelistet, Claude-Schema durch ältere IDs belegt). Die exakten Strings sollte man nach dem ersten Lauf noch über `~/.copilot/settings.json` bestätigen.
- Ursprünglich stand hier „GPT-6.1 Astra“; gemeint war GPT-6.1 Sol. Die Agents heißen deshalb `implementer-sol` und `reviewer-sol`.
- Nach den ersten Läufen sollte man in `~/.copilot/logs/` prüfen, ob die Subagenten wirklich mit ihrem eigenen Modell laufen.
- Ob die Kreuzprüfung sich im Verhältnis zu ihren Kosten lohnt, zeigt sich erst im Alltag.
- Beim Ultra-Modus ist offen, ob Opus die Befundliste und die Abbruchregeln ohne Skript-Laufzeit zuverlässig einhält.
