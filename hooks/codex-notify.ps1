[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$PayloadParts
)

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$Notifier = Join-Path $RootDir "scripts/notify-agent.ps1"

function Convert-ValueToMessage {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) {
    return ""
  }

  if ($Value -is [string]) {
    return $Value
  }

  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $items = @($Value)
    if ($items.Count -gt 0) {
      return Convert-ValueToMessage $items[-1]
    }
    return ""
  }

  return ($Value | ConvertTo-Json -Compress -Depth 8)
}

$rawPayload = ""

if ($PayloadParts.Count -gt 0) {
  $rawPayload = $PayloadParts[0]
  if ([string]::IsNullOrWhiteSpace($rawPayload) -and $PayloadParts.Count -gt 1) {
    $rawPayload = ($PayloadParts -join " ")
  }
}

if ([Console]::IsInputRedirected -and [string]::IsNullOrWhiteSpace($rawPayload)) {
  $rawPayload = [Console]::In.ReadToEnd()
}

$message = $rawPayload

if (-not [string]::IsNullOrWhiteSpace($rawPayload)) {
  try {
    $payload = $rawPayload | ConvertFrom-Json -ErrorAction Stop
    $candidates = @(
      $payload."last-assistant-message",
      $payload.last_assistant_message,
      $payload.message,
      $payload.body,
      $payload.content,
      $payload."input-messages",
      $payload.input_messages,
      $payload.type
    )

    foreach ($candidate in $candidates) {
      $candidateMessage = Convert-ValueToMessage $candidate
      if (-not [string]::IsNullOrWhiteSpace($candidateMessage)) {
        $message = $candidateMessage
        break
      }
    }
  } catch {
  }
}

& $Notifier `
  -Source "codex" `
  -Event "completed" `
  -Title "Codex Complete" `
  -Message $message `
  -Sound $true
