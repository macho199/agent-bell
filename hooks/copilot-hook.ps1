[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$Notifier = Join-Path $RootDir "scripts/notify-agent.ps1"

$rawPayload = ""
if ([Console]::IsInputRedirected) {
  $rawPayload = [Console]::In.ReadToEnd()
}

if ([string]::IsNullOrWhiteSpace($rawPayload)) {
  return
}

try {
  $payload = $rawPayload | ConvertFrom-Json -ErrorAction Stop
} catch {
  return
}

$reason = [string]$payload.reason

switch ($reason) {
  "complete" {
    & $Notifier `
      -Source "copilot" `
      -Event "completed" `
      -Title "Copilot Complete" `
      -Message "" `
      -Sound $true
  }
  "error" {
    & $Notifier `
      -Source "copilot" `
      -Event "completed" `
      -Title "⚠️ Copilot Error" `
      -Message "An error occurred during the session" `
      -Sound $true
  }
  default {
  }
}
