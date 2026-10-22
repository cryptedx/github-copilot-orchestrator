# Zeigt, mit welchem Modell jeder Subagent einer Copilot-Session lief.
# Aufruf: powershell -ExecutionPolicy Bypass -File .\tools\check-session.ps1 [Session-ID | Pfad zu events.jsonl]
# Ohne Argument nimmt das Skript die zuletzt geänderte Session.
# Exit-Code 1, wenn ein Subagent mit einem anderen Modell lief als in seiner Agent-Datei.
param([string]$Session)
$ErrorActionPreference = 'Stop'

$AgentKeys = 'agentname','customagentname','subagentname','agenttype','agent_type','subagenttype','subagent_type','agent','name'
$ModelKeys = 'resolvedmodel','subagentmodel','model'
$SourceKeys = 'modelselectionsource','taskmodelsource'
$EffortKeys = 'reasoningeffort','reasoning_effort','effort'
$ContextKeys = 'contexttier','context_tier'
$DispatchTools = 'task','agent','custom-agent','custom_agent','runsubagent'

$CopilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' }
$StateDir = Join-Path $CopilotHome 'session-state'

function Find-Events([string]$arg) {
    if ($arg) {
        if (Test-Path $arg -PathType Leaf) { return (Resolve-Path $arg).Path }
        if (Test-Path $arg -PathType Container) { return Join-Path $arg 'events.jsonl' }
        return Join-Path (Join-Path $StateDir $arg) 'events.jsonl'
    }
    $files = Get-ChildItem -Path $StateDir -Directory | ForEach-Object { Join-Path $_.FullName 'events.jsonl' } |
        Where-Object { Test-Path $_ } | ForEach-Object { Get-Item $_ }
    if (-not $files) { throw 'Keine Session mit events.jsonl gefunden.' }
    return ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Get-ExpectedModels {
    $models = @{}
    $agentsDir = if ($env:COPILOT_AGENTS_DIR) { $env:COPILOT_AGENTS_DIR } else { Join-Path $CopilotHome 'agents' }
    foreach ($d in @($agentsDir, (Join-Path (Split-Path $PSScriptRoot -Parent) 'agents'))) {
        if (-not (Test-Path $d -PathType Container)) { continue }
        foreach ($f in Get-ChildItem -Path $d -Filter '*.agent.md' -File | Sort-Object Name) {
            $text = Get-Content -Raw -Encoding UTF8 $f.FullName
            $n = [regex]::Match($text, '(?m)^name:\s*(\S+)')
            $m = [regex]::Match($text, '(?m)^model:\s*(\S+)')
            if ($n.Success -and $m.Success) {
                $key = $n.Groups[1].Value.Trim("'", '"')
                if (-not $models.ContainsKey($key)) { $models[$key] = $m.Groups[1].Value.Trim("'", '"') }
            }
        }
    }
    return $models
}

# Alle Blattwerte nach kleingeschriebenem Schlüssel, erster Treffer gewinnt.
function Get-Flat($obj, [hashtable]$out) {
    if ($null -eq $obj) { return $out }
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $obj.PSObject.Properties) {
            $v = $p.Value
            if ($v -is [System.Management.Automation.PSCustomObject] -or ($v -is [System.Collections.IEnumerable] -and $v -isnot [string])) {
                [void](Get-Flat $v $out)
            } elseif (-not $out.ContainsKey($p.Name.ToLower())) {
                $out[$p.Name.ToLower()] = $v
            }
        }
    } elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        foreach ($v in $obj) { [void](Get-Flat $v $out) }
    }
    return $out
}

function Get-First([hashtable]$flat, [string[]]$keys) {
    foreach ($k in $keys) {
        if ($flat.ContainsKey($k) -and "$($flat[$k])" -ne '') { return "$($flat[$k])" }
    }
    return ''
}

$path = Find-Events $Session
if (-not (Test-Path $path -PathType Leaf)) { throw "Nicht gefunden: $path" }
$expected = Get-ExpectedModels

$events = foreach ($line in Get-Content -Encoding UTF8 $path) {
    try { $line | ConvertFrom-Json } catch { }
}
$started = @($events | Where-Object { "$($_.type)" -match 'subagent.*start' })
$kind = 'subagent.started'
if ($started.Count -eq 0) {
    # Ersatz: die Aufrufe des Werkzeugs, das Subagenten startet
    $started = @($events | Where-Object {
        $_.type -eq 'tool.execution_start' -and $DispatchTools -contains ("$((Get-Flat $_.data @{})['toolname'])".ToLower())
    })
    $kind = 'Werkzeugaufruf'
}

Write-Host "Session: $(Split-Path (Split-Path $path -Parent) -Leaf)  ($($started.Count) x $kind)"
if ($started.Count -eq 0) { Write-Host 'Keine Subagenten gestartet.'; exit 0 }

$mismatches = 0
$unknownAgent = $false
$rows = foreach ($e in $started) {
    $flat = Get-Flat $e.data @{}
    $agent = Get-First $flat $AgentKeys
    $model = Get-First $flat $ModelKeys
    $want = if ($agent -and $expected.ContainsKey($agent)) { $expected[$agent] } else { '' }
    $source = (@($SourceKeys | ForEach-Object { Get-First $flat @($_) } | Where-Object { $_ }) -join '/')
    if (-not $want -or -not $model) { $status = '?' }
    elseif ($model -eq $want) { $status = 'ok' }
    else { $status = 'ABWEICHUNG'; $mismatches++ }
    if (-not $agent) { $unknownAgent = $true; $agent = '?' }
    $ts = "$($e.timestamp)"
    [pscustomobject]@{
        Zeit      = if ($ts.Length -ge 19) { $ts.Substring(11, 8) } else { $ts }
        Agent     = $agent
        Modell    = if ($model) { $model } else { '?' }
        Erwartet  = if ($want) { $want } else { '-' }
        Quelle    = $source
        Reasoning = Get-First $flat $EffortKeys
        Kontext   = Get-First $flat $ContextKeys
        Status    = $status
    }
}
$rows | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
if ($mismatches) { Write-Host "$mismatches Subagent-Start(s) mit anderem Modell als in der Agent-Datei." }
if ($unknownAgent) { Write-Host 'Hinweis: Agent-Name nicht erkannt. Bitte eine Zeile aus events.jsonl ins Issue kopieren.' }
exit ([int]($mismatches -gt 0))
