[CmdletBinding()]
param(
  [string]$Source = "agent",
  [string]$Event = "notification",
  [string]$Title = "Agent Bell Notification",
  [string]$Message = "",
  [bool]$Sound = $false
)

$ErrorActionPreference = "Stop"

$LogFile = if ($env:AGENT_BELL_LOG_FILE) {
  $env:AGENT_BELL_LOG_FILE
} else {
  Join-Path ([System.IO.Path]::GetTempPath()) "agent-bell.log"
}

$DedupeDir = if ($env:AGENT_BELL_DEDUPE_DIR) {
  $env:AGENT_BELL_DEDUPE_DIR
} else {
  Join-Path ([System.IO.Path]::GetTempPath()) "agent-bell-dedupe"
}

$DedupeTtlSeconds = 20
if ($env:AGENT_BELL_DEDUPE_TTL_SECONDS) {
  $parsedTtl = 0
  if ([int]::TryParse($env:AGENT_BELL_DEDUPE_TTL_SECONDS, [ref]$parsedTtl)) {
    $DedupeTtlSeconds = $parsedTtl
  }
}

function Write-LogLine {
  param([string]$Line)

  try {
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
    Add-Content -Path $LogFile -Value "$timestamp $Line" -Encoding UTF8
  } catch {
  }
}

function Normalize-Text {
  param([AllowNull()][object]$Text)

  if ($null -eq $Text) {
    return ""
  }

  return (($Text.ToString() -replace "\s+", " ").Trim())
}

function Get-FallbackMessage {
  param([string]$EventName)

  switch ($EventName) {
    "question" { return "User input or approval is required" }
    default { return "Task complete" }
  }
}

function Get-DecoratedTitle {
  param(
    [string]$EventName,
    [string]$RawTitle
  )

  if ($RawTitle -match "^(🔔 |❓ |⚠️ )") {
    return $RawTitle
  }

  switch ($EventName) {
    "question" { return "❓ $RawTitle" }
    default { return "🔔 $RawTitle" }
  }
}

$Source = Normalize-Text $Source
$Event = Normalize-Text $Event
$Title = Normalize-Text $Title
$Message = Normalize-Text $Message

if ([string]::IsNullOrWhiteSpace($Source)) {
  $Source = "agent"
}

if ([string]::IsNullOrWhiteSpace($Event)) {
  $Event = "notification"
}

if ([string]::IsNullOrWhiteSpace($Title)) {
  $Title = "Agent Bell Notification"
}

if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = Get-FallbackMessage $Event
}

$Title = Get-DecoratedTitle -EventName $Event -RawTitle $Title

try {
  New-Item -ItemType Directory -Path $DedupeDir -Force | Out-Null
} catch {
}

$hashInput = "$Source`n$Event`n$Message"
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
$sha256.Dispose()
$hashKey = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
$stateFile = Join-Path $DedupeDir $hashKey
$nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

if (Test-Path -LiteralPath $stateFile) {
  try {
    $previousEpoch = [long](Get-Content -LiteralPath $stateFile -Raw)
    $ageSeconds = $nowEpoch - $previousEpoch
    if ($ageSeconds -ge 0 -and $ageSeconds -lt $DedupeTtlSeconds) {
      Write-LogLine "deduped source=$Source event=$Event title=""$Title"""
      return
    }
  } catch {
  }
}

try {
  Set-Content -LiteralPath $stateFile -Value $nowEpoch -Encoding ASCII
} catch {
}

Write-LogLine "dispatch source=$Source event=$Event title=""$Title"""

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  Write-LogLine "skip_non_windows source=$Source event=$Event title=""$Title"""
  return
}

try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
  $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
  $notifyIcon.Visible = $true
  $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
  $notifyIcon.BalloonTipTitle = $Title
  $notifyIcon.BalloonTipText = $Message

  if ($Sound) {
    try {
      [console]::Beep(880, 160)
    } catch {
    }
  }

  $notifyIcon.ShowBalloonTip(5000)
  Start-Sleep -Milliseconds 5500
  $notifyIcon.Dispose()
} catch {
  Write-LogLine "notify_failed source=$Source event=$Event error=""$($_.Exception.Message)"""
}
