param(
  [string]$EnvName = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Write-Information -InformationAction Continue -MessageData "[example_post] Running for environment: $EnvName"
Write-Information -InformationAction Continue -MessageData "Goodbye from example_post.ps1"

