# GitHub Copilot Orchestrator

Ein Set aus Custom Agents für GitHub Copilot (App und CLI), das bei der Arbeit Budget spart. Ein starkes Modell plant und entscheidet. Günstigere Modelle aus zwei Familien lesen, schreiben, testen und prüfen sich gegenseitig.

> Hintergrund: Seit dem 1. Juni 2026 rechnet Copilot nach Tokens ab (GitHub AI Credits). Teuer wird ein großes Modell vor allem dann, wenn es viel Code liest, Logs verarbeitet und lange Ausgaben schreibt. Genau diese Arbeit übernehmen hier die günstigen Subagenten.

## Aufbau

| Rolle | Claude-Familie | GPT-Familie |
|---|---|---|
| Orchestrieren (teuer) | `orchestrator` – Opus 5.5 | – |
| Orchestrieren, günstig (mittel) | `orchestrator-lite` – Sonnet 5.5 | – |
| Orchestrieren, gründlich (sehr teuer) | `orchestrator-ultra` – Opus 5.5 | – |
| Selbst umsetzen mit Prüfung (billigst) | `duo-haiku` – Haiku 5.5 | `duo-luna` – GPT-6 Luna |
| Erkunden (billig) | `scout` – Haiku 5.5 | `scout-luna` – GPT-6 Luna |
| Umsetzen (mittel) | `implementer` – Sonnet 5.5 | `implementer-sol` – GPT-6.1 Sol |
| Code prüfen (mittel) | `reviewer` – Sonnet 5.5 | `reviewer-sol` – GPT-6.1 Sol |
| Kleine Änderungen prüfen (billigst) | `reviewer-haiku` – Haiku 5.5 | `reviewer-luna` – GPT-6 Luna |
| Tests/Builds ausführen (billigst) | – | `runner` – GPT-6 Luna |
| Pläne hinterfragen (billigst) | – | `challenger` – GPT-6 Luna |

### Pflicht zur Delegation

Alle Orchestratoren setzen Code nicht selbst um, sondern delegieren:

- Jede Datei- oder Code-Änderung geht an einen Implementer, und danach prüft ein Reviewer der anderen Familie.
- Tests, Builds, Linter und Commits gehen an `runner`. Die Commit-Nachricht gibt der Orchestrator vor.
- Selbst arbeitet der Orchestrator nur bei trivialen Aufgaben, also bei Fragen ohne Code-Lesen oder bei wenigen Zeilen in einer einzigen Datei ohne Tests und ohne Commit.
- Die Regel gilt auch im Autopilot und wenn der Orchestrator mitten in einer Session neu gewählt wird.
- Der Orchestrator gibt beim Start jedes Subagenten ausdrücklich dessen Modell-ID mit. Sonst laufen Scouts und Runner unter Umständen mit dem Session-Modell.

### Kreuzprüfung

- **Familienwechsel:** Wer umsetzt und wer prüft, gehören zu verschiedenen Familien. Code von Sonnet prüft Sol, Code von Sol prüft Sonnet.
- **Abwechseln:** Aufeinanderfolgende Umsetzungsaufgaben gehen im Wechsel an `implementer` und `implementer-sol`.
- **Scout-Paar:** Große Suchen teilen sich Haiku und Luna parallel. Kritische Aussagen bestätigt der Scout der jeweils anderen Familie unabhängig.
- **Challenger:** Bevor Opus einen nicht-trivialen Plan umsetzen lässt, sucht Luna darin nach Schwachstellen.
- **Verhältnismäßigkeit:** Doppelt geprüft wird nur dort, wo ein Fehler wirklich etwas kostet.

### Duo-Modus

`duo-haiku` und `duo-luna` sind die billigste Stufe für kleine Aufgaben. Es gibt keinen Orchestrator: Das Session-Modell setzt selbst um und testet. Nach jeder Änderung prüft automatisch der Reviewer der anderen Familie.

- Code von `duo-haiku` prüft `reviewer-luna`.
- Code von `duo-luna` prüft `reviewer-haiku`.
- Höchstens zwei Reparaturrunden, danach entscheidet der Nutzer. Ohne Prüfung bleiben nur Tippfehler, Kommentare und Formatierung.

Für Aufgaben mit unklarer Ursache oder vielen Dateien ist `orchestrator-lite` die bessere Wahl. Bei großem Kontext lieber `duo-luna` nehmen, weil Haiku ab 100.000 Tokens das Fünffache kostet.

### Ultra-Modus

`orchestrator-ultra` überträgt die Arbeitsweise des Ultracode-Modus der Claude App auf dieses Agent-Set. Er ist für große Aufgaben gedacht, etwa Audits, Migrationen, schwere Bugs oder Entwürfe mit großem Lösungsraum.

| Muster | Umsetzung |
|---|---|
| Breit erkunden (Multi-modal Sweep) | `scout` und `scout-luna` suchen parallel auf verschiedenen Wegen |
| Weitersuchen bis nichts mehr kommt (Loop-until-dry) | neue Runden, bis zwei hintereinander nichts Neues bringen, höchstens 5 |
| Gegnerisch prüfen (Adversarial Verify) | beide Scouts und `challenger` versuchen, jeden wichtigen Befund zu widerlegen; er gilt, wenn 2 von 3 scheitern. Löst der Befund eine Code-Änderung aus, prüft statt `challenger` der Reviewer der anderen Familie |
| Entwürfe gegeneinander (Judge Panel) | `implementer` und `implementer-sol` entwerfen, beide Reviewer bewerten, Opus entscheidet |
| Umsetzen mit Prüfschleife | andere Familie prüft, `runner` testet, höchstens zwei Reparaturrunden |
| Fragen, was fehlt (Completeness Critic) | `challenger` sucht am Ende jeder Phase nach Lücken |

Anders als in der Claude App gibt es in Copilot keine Laufzeit, die so einen Ablauf als Skript ausführt. Den Ablauf steuert Opus selbst und führt dafür eine Befundliste. Zählen und Abbrechen sind deshalb weniger verlässlich als im Original.

Der Ultra-Modus kostet ein Vielfaches des normalen Orchestrators. Für alltägliche Aufgaben bleibt `orchestrator` die bessere Wahl.

### Kosten (Schätzung)

Grob geschätzt nach den [Copilot-Preisen](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing) vom Oktober 2026. Gemessen ist das nicht, den echten Verbrauch zeigt GitHub unter Settings → Billing.

| Aufgabe | Kosten |
|---|---:|
| Kleine Aufgabe mit `orchestrator` | $0,50–1 |
| Mittleres Feature mit `orchestrator` | $1,50–3 |
| Großes Audit oder Migration mit `orchestrator-ultra` | $4–10 |

Das meiste Geld geht an Opus und an die Aufträge für Sonnet und Sol. Haiku und Luna kosten pro Token ein Zwanzigstel davon. Am teuersten wird es, wenn der Cache verfällt: Lässt du eine Session länger liegen, kostet jede Opus-Runde danach den vollen Input-Preis. Haiku kostet außerdem ab 100.000 Tokens Kontext das Fünffache, deshalb gehen große Suchen an `scout-luna`.

Jeder Aufruf des Orchestrators schickt seinen ganzen Kontext mit. Liest, editiert oder testet er selbst, wächst dieser Kontext schnell, und jede weitere Runde wird teurer. In einer gemessenen Session kostete der Opus-Orchestrator so rund 8 AIU pro Aufruf, ein Sonnet-Subagent rund 3 AIU. So hältst du die Kosten niedrig:

- Für Alltagsaufgaben mit klarem Plan `orchestrator-lite` nehmen. Er plant mit Sonnet statt Opus und delegiert genauso.
- Für jede unabhängige Aufgabe eine neue Session starten, statt eine lange Session immer wieder fortzusetzen.
- Den Orchestrator nicht selbst arbeiten lassen. Siehe [Pflicht zur Delegation](#pflicht-zur-delegation).

## Installation

### Agents

Persönlich, also für alle Repos:

macOS und Linux:

```bash
./install.sh
```

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Beide Skripte kopieren `agents/*.agent.md` nach `~/.copilot/agents/`, unter Windows also nach `%USERPROFILE%\.copilot\agents\`. Weicht eine vorhandene Datei ab, legen sie vorher eine `.bak`-Sicherung an. Ein anderes Ziel setzt du mit der Umgebungsvariable `COPILOT_AGENTS_DIR`. Alternativ legst du die Dateien für ein einzelnes Repo nach `.github/agents/`.

### Skills (z. B. von Matt Pocock)

Skills liegen jeweils in einem eigenen Ordner mit einer `SKILL.md`:

- persönlich: `~/.copilot/skills/<skill-name>/SKILL.md` (alternativ `~/.agents/skills/`)
- pro Repo: `.github/skills/`, `.claude/skills/` oder `.agents/skills/`

Installieren:

```bash
# per Copilot CLI
copilot skill add <Datei | URL | Ordner>

# Matt-Pocock-Skills per npx (danach ggf. nach ~/.copilot/skills/ verschieben)
npx skills@latest add mattpocock/skills/<skill-name>
```

Danach eine neue Session starten oder `/skills reload` ausführen. Mit `/skills info <name>` siehst du, ob der Skill geladen ist. In der Copilot App findest du Skills zusätzlich unter **Einstellungen → Skills**.

## Benutzung

1. In der Copilot App den Agenten wählen und das passende Session-Modell einstellen:
   - **`orchestrator`** mit **Opus 5.5** für den Normalfall
   - **`orchestrator-lite`** mit **Sonnet 5.5** für Alltagsaufgaben mit klarem Plan
   - **`orchestrator-ultra`** mit **Opus 5.5** für große Aufgaben
   - **`duo-haiku`** mit **Haiku 5.5** oder **`duo-luna`** mit **GPT-6 Luna** für kleine Aufgaben
2. Den Skill wie gewohnt aufrufen, z. B. „Nutze /tdd für …“.

Der Orchestrator folgt dem Ablauf des Skills und entscheidet pro Schritt nur, **wer** ihn ausführt. Subagenten erben keine Skills, deshalb gibt Opus ihnen die nötigen Regeln aus dem Skill im Auftrag mit.

Für kleine Aufgaben ist ein Duo oder eine direkte Session mit Sonnet 5.5 ohne Orchestrator oft günstiger, weil auch die Delegation Tokens kostet.

## Modell-IDs

Im `model:`-Feld steht die Modell-ID: kleingeschrieben, ohne Anführungszeichen, als einzelner String. Den Anzeigenamen aus dem Modell-Picker versteht die Runtime hier nicht.

| Modell | ID | Status |
|---|---|---|
| GPT-6 Luna | `gpt-6-luna` | belegt |
| GPT-6.1 Sol | `gpt-6.1-sol` | Modell in der GitHub-Doku gelistet, ID abgeleitet |
| Claude Opus 5.5 | `claude-opus-5.5` | Modell in der GitHub-Doku gelistet, ID-Schema belegt |
| Claude Sonnet 5.5 | `claude-sonnet-5.5` | Modell in der GitHub-Doku gelistet, ID-Schema belegt |
| Claude Haiku 5.5 | `claude-haiku-5.5` | Modell in der GitHub-Doku gelistet, ID-Schema belegt |

Das Schema `claude-<familie>-<version>` ist durch ältere IDs wie `claude-sonnet-4.6` aus `~/.copilot/logs/` belegt. Die Modelle selbst stehen in [Supported AI models](https://docs.github.com/en/copilot/reference/ai-models/supported-models) (Stand 19.10.2026).

**Prüfen:** In der Copilot CLI mit `/model` ein Modell wählen und dann in `~/.copilot/settings.json` nachsehen, welcher Wert bei `"model"` steht. Das ist die exakte ID.

## Bekannte Stolperfallen

- **Stilles Herabstufen:** Hat ein Subagent ein teureres Modell als die Session, stuft die Runtime ihn ohne sichtbare Warnung auf das Session-Modell herab. Der Hinweis steht nur im Log unter `~/.copilot/logs/`. Die Session sollte deshalb mit dem größten Modell laufen, das ein Subagent braucht. Bei `orchestrator` und `orchestrator-ultra` ist das Opus 5.5. Bei `orchestrator-lite` reicht Sonnet 5.5. In den Duos läuft der Reviewer mit dem Modell der anderen Familie. Ist es teurer als das Session-Modell, prüft am Ende dasselbe Modell, das umgesetzt hat. Das zeigt dann ebenfalls das Log. Ist Sol teurer als Sonnet, wird `implementer-sol` dort herabgestuft. Das zeigt dann das Log.
- **Subagent läuft mit dem Session-Modell:** In echten Sessions liefen `scout`, `challenger` und `implementer-sol` mit dem Modell des Orchestrators, weil dieser beim Delegieren sein eigenes Modell vorgab (im Log `explicitModelOverride`). Ein Verbot im Prompt half nicht. Deshalb geben die Orchestratoren seit v1.4.1 immer die richtige ID ausdrücklich mit, und die Runtime übernimmt sie. Prüfen kannst du das in `events.jsonl` der Session bei `subagent.started`.
- **Kein Array im `model:`-Feld:** VS Code akzeptiert eine Liste von Modellen, die CLI und die App nicht.
- **Kosten der Kreuzprüfung:** Jede Gegenprüfung verdoppelt die Kosten für diesen Schritt. Prüft der Orchestrator zu eifrig, schärfst du den Abschnitt „Verhältnismäßigkeit“ in `agents/orchestrator.agent.md` nach.

## Quellen

- [GitHub Copilot is moving to usage-based billing](https://github.blog/news-insights/github-copilot-is-moving-to-usage-based-billing/)
- [About custom agents – GitHub Docs](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/agents/copilot-cli/about-custom-agents)
- [Customizing the GitHub Copilot app – GitHub Docs](https://docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app)
- [Adding agent skills for GitHub Copilot CLI – GitHub Docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
- [copilot-cli #3565 – Subagent model downgrade](https://github.com/github/copilot-cli/issues/3565)
- [copilot-cli #2133 – model als Array](https://github.com/github/copilot-cli/issues/2133)
- [gh-aw #64965 – gpt-6-luna](https://github.com/github/gh-aw/issues/64965)

## Lizenz

[MIT](LICENSE)
