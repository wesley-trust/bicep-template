[CmdletBinding()]
Param(
  [string]$DesignRoot = "./tests/design/resource_group",
  [string]$Location = $ENV:REGION,
  [string]$RegionCode = $ENV:REGIONCODE,
  [string]$Environment = $ENV:ENVIRONMENT,
  [ValidateSet("Full", "Environment", "Region")][string]$DesignPathSwitch = "Region",
  [string]$ResourceGroupTemplateFile = "./platform/resourcegroup.bicep",
  [string]$ResourceGroupParameterFile = "./platform/resourcegroup.bicepparam",
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
  
  # Optional skip matrix for resource properties
  $script:PropertySkipMatrix = @{}
}

BeforeAll {
  
  # Generate Bicep Report
  $Report = az deployment sub what-if --location $Location --template-file $ResourceGroupTemplateFile --parameters $ResourceGroupParameterFile --only-show-errors --no-pretty-print

  # Create object if report is not null or empty, and optionally publish artifact
  if ($Report) {
    if ($ENV:PUBLISHTESTARTIFACTS) {
      $Report | Out-File -FilePath "$ENV:BUILD_ARTIFACTSTAGINGDIRECTORY/bicep.report.json"
    }
    $ReportObject = $Report | ConvertFrom-Json

    $ReportFiltered = $ReportObject.changes.after
  }
  else {
    throw "Operation failed or returned no results."
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
    $Tags = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).tags

    if ($null -ne $Tags) {
      $TagsObject = @(
        $Tags.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }
    else {
      $TagsObject = @()
    }
  }

  BeforeAll {
    
    $ResourceType = $_

    $Resources = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).resources
    $Tags = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).tags

    if ($null -ne $Tags) {
      $TagsObject = @(
        $Tags.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }
    else {
      $TagsObject = @()
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
    
    It "should have at least one Tag" {

      # Act
      $ActualValue = $TagsObject.Count

      # Assert
      $ActualValue | Should -BeGreaterThan 0
    }
  }

  Context "Resource Name '<_.name>'" -ForEach $Resources {

    BeforeDiscovery {
      
      $Resource = $_

      $PropertiesObject = @(
        $Resource.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }

    BeforeAll {
      
      $Resource = $_
      
      $PropertiesObject = @(
        $Resource.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
      
      $ReportResource = $ReportResources | Where-Object { $_.name -eq $Resource.Name }
    }

    Context "Integrity Check" {
      
      It "should have at least one Property" {
        
        # Act
        $ActualValue = $PropertiesObject.Count

        # Assert
        $ActualValue | Should -BeGreaterThan 0
      }
    }

    Context "Properties" {
      
      It "should have property '<_.Name>' with value '<_.Value>'" -ForEach $PropertiesObject {
        
        # Arrange
        $Property = $_
        
        # Act
        # Skip when the property is disabled for this resource type
        $PropertyValue = $PropertySkipMatrix[$ResourceType]?[$Property.Name]
        $SkipProperty = $PropertyValue ? [bool]::Parse($PropertyValue) : $false

        if ($SkipProperty) {
          Set-ItResult -Skipped -Because "it is not applicable for this test"
        }

        $ActualValue = $ReportResource.$($Property.Name)

        # Assert
        $ActualValue | Should -Be $Property.Value
      }
    }

    Context "Tags" {
      
      It "should have tag '<_.Name>' with value '<_.Value>'" -ForEach $TagsObject {
        
        # Arrange
        $Tag = $_
        
        # Act
        $ActualValue = $ReportResource.Tags.$($Tag.Name)
        
        # Assert
        $ActualValue | Should -BeExactly $Tag.Value
      }
    }
  }
}
