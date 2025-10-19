[CmdletBinding()]
Param(
  [string]$DesignRoot = "./tests/design/resource_group",
  [string]$Location = $ENV:REGION,
  [string]$RegionCode = $ENV:REGIONCODE,
  [string]$Environment = $ENV:ENVIRONMENT,
  [ValidateSet("Full", "Environment", "Region")][string]$DesignPathSwitch = "Region",
  [string]$ResourceGroupName = $ENV:RESOURCEGROUP,
  [string]$Name
)

BeforeDiscovery {

  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Version Latest

  # Determine Design Path
  switch ($DesignPathSwitch) {
    "Root" {
      $DesignPath = "$DesignRoot"
    }
    "Environment" {
      $DesignPath = "$DesignRoot/environments/$Environment"
    }
    "Region" {
      $DesignPath = "$DesignRoot/environments/$Environment/regions/$RegionCode"
    }
  }

  # Import Design
  if (Test-Path -Path $DesignPath -PathType Container) {
    $DesignFiles = Get-ChildItem -Path $DesignPath -Filter "*.design.json" -File | Sort-Object -Property Name

    if (!$DesignFiles) {
      throw "No design files found in '$DesignPath'."
    }

    # Build Design JSON array from multiple files
    $script:Design = foreach ($File in $DesignFiles) {
      $Content = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json

      if ($Content -is [System.Array]) {
        $Content
      }
      else {
        @($Content)
      }
    }
  }
  else {
    $script:Design = Get-Content -Path $DesignPath -Raw | ConvertFrom-Json
  }

  # Get unique Resource Types
  $script:ResourceTypes = $Design.resourceType | Sort-Object -Unique
}

BeforeAll {

  # Subscription Stack
  $StackSubName = "ds-sub-$ResourceGroupName"

  $StackSubParameters = @(
    'stack', 'sub', 'show',
    '--name', $StackSubName,
    '--only-show-errors'
  )

  # Show Stack
  $Report = az @StackSubParameters
  
  # Create object if report is not null or empty, and optionally publish artifact
  if ($Report) {
    if ($ENV:PUBLISHTESTARTIFACTS) {
      $Report | Out-File -FilePath "$ENV:BUILD_ARTIFACTSTAGINGDIRECTORY/bicep.report.json"
    }
    
    $ReportObject = $Report | ConvertFrom-Json

    if ($ReportObject.resources) {
      $ReportFiltered = foreach ($ResourceId in $ReportObject.resources.id) {     
        $Resource = Get-AzResourceGroup -ResourceId $ResourceId

        [PSCustomObject]@{
          Name              = $Resource.ResourceGroupName
          Type              = "Microsoft.Resources/resourceGroups"
          ProvisioningState = $Resource.ProvisioningState
        }
      }
    }
  }
  else {
    Write-Information -InformationAction Continue -MessageData "No resources found in stack '$StackSubName'."
  }
}

Describe "Resource Design" {
  
  Context "Integrity Check" {
    
    It "should have at least one Resource Type" {

      # Act
      $ActualValue = @($ResourceTypes).Count

      # Assert
      $ActualValue | Should -BeGreaterThan 0
    }
  }
}

Describe "Resource Type '<_>'" -ForEach $ResourceTypes {

  BeforeDiscovery {
    
    $ResourceType = $_

    $Resources = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).resources
    $Health = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).health

    if ($null -ne $Health) {
      $HealthObject = @(
        $Health.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }
    else {
      $HealthObject = @()
    }
  }

  BeforeAll {
    
    $ResourceType = $_

    $Resources = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).resources
    $Health = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).health

    if ($null -ne $Health) {
      $HealthObject = @(
        $Health.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }
    else {
      $HealthObject = @()
    }
    
    $ReportResources = $ReportFiltered | Where-Object { $_.type -eq $ResourceType }
  }

  Context "Integrity Check" {
    
    It "should have at least one Resource" {

      # Act
      $ActualValue = @($Resources).Count

      # Assert
      $ActualValue | Should -BeGreaterThan 0
    }
    
    It "should have at least one Health property" {

      # Act
      $ActualValue = $HealthObject.Count

      # Assert
      $ActualValue | Should -BeGreaterThan 0
    }
  }

  Context "Resource Name '<_.name>'" -ForEach $Resources {

    BeforeAll {

      $Resource = $_
      
      $ReportResource = $ReportResources | Where-Object { $_.name -eq $Resource.Name }
    }

    Context "Health Properties" {
      
      It "should have health property '<_.Name>' with value '<_.Value>'" -ForEach $HealthObject {
        
        # Arrange
        $Health = $_

        # Act
        $ActualValue = $ReportResource.$($Health.Name)

        # Assert
        $ActualValue | Should -BeExactly $Health.Value
      }
    }
  }
}