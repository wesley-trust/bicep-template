param(
  [Parameter(Mandatory = $true)][string]$PathRoot,
  [Parameter(Mandatory = $true)][string]$Type,
  [Parameter(Mandatory = $true)][string]$ResultsFile,
  [string]$ResultsFormat = 'NUnitXml',
  [hashtable]$TestData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
  if (-not (Get-Module -ListAvailable -Name Pester)) {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-Module Pester -Scope CurrentUser -Force
  }
  Import-Module Pester

  $dir = Split-Path -Path $ResultsFile -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  # Install the Az module if not already available
  if (-not (Get-Module -ListAvailable -Name Az)) {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-Module -Name Az -Scope CurrentUser -Force
  }

  # Using Environment variables set by the AzureCLI@2 task
  Connect-AzAccount -ServicePrincipal `
    -Tenant $env:tenantId `
    -ApplicationId $env:servicePrincipalId `
    -FederatedToken $env:idToken

  $containerArgs = @{ Path = "$PathRoot/$Type/$($TestData.Name)" }
  if ($PSBoundParameters.ContainsKey('TestData') -and $null -ne $TestData) {
    $containerArgs.Data = $TestData
  }

  $configuration = New-PesterConfiguration
  $configuration.Run.Container = @(New-PesterContainer @containerArgs)
  $configuration.Run.Exit = $true
  $configuration.Output.Verbosity = "Detailed"
  $configuration.TestResult.Enabled = $true
  $configuration.TestResult.OutputFormat = $ResultsFormat
  $configuration.TestResult.OutputPath = $ResultsFile

  Invoke-Pester -Configuration $configuration
}
catch {
  Write-Error $_
  throw
}
