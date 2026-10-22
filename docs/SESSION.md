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

8. **Pflicht zur Delegation (20. Oktober 2026).** In einer echten Session hat der Orchestrator im Autopilot selbst editiert, getestet und committet (Issue #1). Seitdem gilt eine feste Regel: Änderungen gehen an einen Implementer, danach prüft ein Reviewer der anderen Familie. Tests, Builds und Commits gehen an `runner`. Selbst arbeitet der Orchestrator nur bei trivialen Aufgaben. Subagenten bekommen kein Modell-Override mehr.
9. **`orchestrator-lite` auf Sonnet (20. Oktober 2026).** Der Opus-Orchestrator kostete in derselben Session fast so viel wie alle Subagenten zusammen (Issue #2). Für Alltagsaufgaben gibt es deshalb eine Variante auf Sonnet. Dazu kommen Regeln, die den eigenen Kontext des Orchestrators klein halten.

10. **Modell-ID ausdrücklich mitgeben (20. Oktober 2026).** Auch mit `orchestrator-lite` lief `scout` auf Sonnet statt Haiku. Die Session kostete 112 AI Credits. Das Verbot eines Modell-Overrides hat nicht gegriffen. Ein ausdrückliches Modell übernimmt die Runtime aber. Seitdem steht die ID jeder Rolle in der Tabelle des Orchestrators, und er gibt sie bei jedem Start mit.
11. **Duo-Modus mit Haiku und Luna (21. Oktober 2026).** Für kleine Aufgaben ist selbst `orchestrator-lite` zu teuer. `duo-haiku` und `duo-luna` setzen deshalb selbst um. Jede Änderung prüft automatisch ein billiger Reviewer der anderen Familie: `reviewer-luna` für Haiku, `reviewer-haiku` für Luna. Die Kreuzprüfung bleibt so erhalten, ohne dass Opus oder Sonnet mitlaufen.
12. **Prüfpflicht im Duo verschärft (21. Oktober 2026).** In der ersten echten Session hat `duo-haiku` bei drei Prompts kein einziges Mal `reviewer-luna` aufgerufen. Werkzeuge fehlten nicht: Ohne `tools:`-Feld steht auch `agent` zur Verfügung. Der Prüfschritt stand aber erst in Schritt 3 des Ablaufs, und die Ausnahme für triviale Änderungen ließ Spielraum. Jetzt steht die Pflicht ganz oben, sie nennt das Werkzeug, gilt bei jeder geänderten Datei und endet mit einer festen Zeile `Prüfung: …`, an der man das Überspringen sieht.

13. **Vorrang der Modell-IDs und Prüfskript (22. Oktober 2026).** Eine Tier-Regel in den eigenen Custom Instructions ließ `reviewer-luna` auf Sonnet 5.5 mit Reasoning `max` laufen (Issue #4). Die Regel liegt nicht in diesem Repo. Die Agents, die Subagenten starten, beanspruchen jetzt Vorrang für ihre Modell-IDs und setzen `reasoningEffort` und `contextTier` nicht. `tools/check-session` zeigt nach jeder Session, ob ein Subagent mit einem anderen Modell lief.

## Offene Punkte

- Die abgeleiteten Modell-IDs (`claude-opus-5.5`, `claude-sonnet-5.5`, `claude-haiku-5.5`, `gpt-6.1-sol`) sind gegen die GitHub-Doku geprüft (alle Modelle gelistet, Claude-Schema durch ältere IDs belegt). Die exakten Strings sollte man nach dem ersten Lauf noch über `~/.copilot/settings.json` bestätigen.
- Ursprünglich stand hier „GPT-6.1 Astra“; gemeint war GPT-6.1 Sol. Die Agents heißen deshalb `implementer-sol` und `reviewer-sol`.
- Nach den ersten Läufen sollte man in `~/.copilot/logs/` prüfen, ob die Subagenten wirklich mit ihrem eigenen Modell laufen.
- Copilot kennt keine Rangfolge zwischen Agent-Prompt und Custom Instructions. Ob der beanspruchte Vorrang der Modell-IDs gegen eine Tier-Regel gewinnt, zeigt erst eine echte Session. Die Feldnamen in `subagent.started` sind aus Issue #4 übernommen und nicht an einem echten Log getestet.
- Ob die Kreuzprüfung sich im Verhältnis zu ihren Kosten lohnt, zeigt sich erst im Alltag.
- Ob `orchestrator-lite` Pläne zuverlässig genug macht, zeigt erst der Vergleich mit `orchestrator` im Alltag. Offen ist auch, ob Sol teurer als Sonnet ist. Dann würde `implementer-sol` in einer Sonnet-Session herabgestuft.
- Beim Ultra-Modus ist offen, ob Opus die Befundliste und die Abbruchregeln ohne Skript-Laufzeit zuverlässig einhält.
