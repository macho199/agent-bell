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

$hookEventName = [string]$payload.hook_event_name

switch ($hookEventName) {
  "Stop" {
    $message = [string]$payload.last_assistant_message
    if ([string]::IsNullOrWhiteSpace($message)) {
      $message = [string]$payload.reason
    }

    & $Notifier `
      -Source "claude" `
      -Event "completed" `
      -Title "Claude Complete" `
      -Message $message `
      -Sound $true
  }
  "Notification" {
  }
  default {
  }
}
