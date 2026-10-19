# GitHub Copilot Orchestrator

Ein Set aus Custom Agents für GitHub Copilot (App und CLI), das bei der Arbeit Budget spart. Ein starkes Modell plant und entscheidet. Günstigere Modelle aus zwei Familien lesen, schreiben, testen und prüfen sich gegenseitig.

> Hintergrund: Seit dem 1. Juni 2026 rechnet Copilot nach Tokens ab (GitHub AI Credits). Teuer wird ein großes Modell vor allem dann, wenn es viel Code liest, Logs verarbeitet und lange Ausgaben schreibt. Genau diese Arbeit übernehmen hier die günstigen Subagenten.

## Aufbau

| Rolle | Claude-Familie | GPT-Familie |
|---|---|---|
| Orchestrieren (teuer) | `orchestrator` – Opus 5.5 | – |
| Erkunden (billig) | `scout` – Haiku 5.5 | `scout-luna` – GPT-6 Luna |
| Umsetzen (mittel) | `implementer` – Sonnet 5.5 | `implementer-sol` – GPT-6.1 Sol |
| Code prüfen (mittel) | `reviewer` – Sonnet 5.5 | `reviewer-sol` – GPT-6.1 Sol |
| Tests/Builds ausführen (billigst) | – | `runner` – GPT-6 Luna |
| Pläne hinterfragen (billigst) | – | `challenger` – GPT-6 Luna |

### Kreuzprüfung

- **Familienwechsel:** Wer umsetzt und wer prüft, gehören zu verschiedenen Familien. Code von Sonnet prüft Sol, Code von Sol prüft Sonnet.
- **Abwechseln:** Aufeinanderfolgende Umsetzungsaufgaben gehen im Wechsel an `implementer` und `implementer-sol`.
- **Scout-Paar:** Große Suchen teilen sich Haiku und Luna parallel. Kritische Aussagen bestätigt der Scout der jeweils anderen Familie unabhängig.
- **Challenger:** Bevor Opus einen nicht-trivialen Plan umsetzen lässt, sucht Luna darin nach Schwachstellen.
- **Verhältnismäßigkeit:** Doppelt geprüft wird nur dort, wo ein Fehler wirklich etwas kostet.

## Installation

### Agents

Persönlich, also für alle Repos:

```bash
./install.sh
```

Das Skript kopiert `agents/*.agent.md` nach `~/.copilot/agents/`. Alternativ legst du die Dateien für ein einzelnes Repo nach `.github/agents/`.

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

1. In der Copilot App den Agenten **`orchestrator`** wählen und als Session-Modell **Opus 5.5** einstellen.
2. Den Skill wie gewohnt aufrufen, z. B. „Nutze /tdd für …“.

Der Orchestrator folgt dem Ablauf des Skills und entscheidet pro Schritt nur, **wer** ihn ausführt. Subagenten erben keine Skills, deshalb gibt Opus ihnen die nötigen Regeln aus dem Skill im Auftrag mit.

Für kleine Aufgaben ist eine direkte Session mit Sonnet 5.5 ohne Orchestrator oft günstiger, weil auch die Delegation Tokens kostet.

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

- **Stilles Herabstufen:** Hat ein Subagent ein teureres Modell als die Session, stuft die Runtime ihn ohne sichtbare Warnung auf das Session-Modell herab. Der Hinweis steht nur im Log unter `~/.copilot/logs/`. Die Session sollte deshalb immer mit dem größten Modell laufen, hier Opus 5.5.
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
