param(
  [string]$EnvName = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Write-Information -InformationAction Continue -MessageData "[example_pre] Running for environment: $EnvName"
Write-Information -InformationAction Continue -MessageData "Hello from example_pre.ps1"

