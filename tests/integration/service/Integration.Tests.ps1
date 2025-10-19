[CmdletBinding()]
Param(
  [string]$DesignRoot = "./tests/design/service",
  [string]$Location = $ENV:REGION,
  [string]$RegionCode = $ENV:REGIONCODE,
  [string]$Environment = $ENV:ENVIRONMENT,
  [ValidateSet("Full", "Environment", "Region")][string]$DesignPathSwitch = "Region",
  [string]$ResourceGroupTemplateFile = "./platform/resourcegroup.bicep",
  [string]$ResourceGroupParameterFile = "./platform/resourcegroup.bicepparam",
  [string]$ResourceTemplateFile = "./platform/service.bicep",
  [string]$ResourceParameterFile = "./platform/service.bicepparam",
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

  # Resource Types to exclude from testing based on environment variables
  $ResourceTypeExclusion = @(
    # Example of excluding based on environment variable
    # if ($ENV:EXCLUDETYPERESOURCETYPE) {
    #   'ResourceType'
    # }
  )

  # Get unique Resource Types, excluding those in the exclusion list
  $script:ResourceTypes = $Design.resourceType | 
  Where-Object { $_ -notin $ResourceTypeExclusion } | 
  Sort-Object -Unique

  # Resource Types that do not have tags
  $script:ResourceTypeTagExclusion = @(
    # Example of how to exclude a resource type that does not have tags
    # 'ResourceType' 
  )

  # Optional skip matrix for resource properties
  $script:PropertySkipMatrix = @{
    # Example of how to skip specific properties for a resource type, which can be controlled via environment variables
    # 'ResourceType' = @{
    #   propertyName = $ENV:EXCLUDEPROPERTYNAMEOFPROPERTY
    # }
  }
}

BeforeAll {

  $StackSubName = "ds-sub-$ResourceGroupName"

  $StackSubParameters = @(
    'stack', 'sub', 'create',
    '--name', $StackSubName,
    '--location', $Location,
    '--template-file', $ResourceGroupTemplateFile,
    '--parameters', $ResourceGroupParameterFile,
    '--deny-settings-mode', 'DenyWriteAndDelete',
    '--action-on-unmanage', 'detachAll',
    '--only-show-errors'
  )

  # Deploy Stack
  $ResourceGroupReport = az @StackSubParameters

  # Validate Resource Group exists
  $ResourceGroupExists = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

  if ($ResourceGroupExists) {

    # Resource Group Stack
    if ($Name) {
      $StackGroupName = "ds-$ResourceGroupName-$Name"
    }
    else {
      $StackGroupName = "ds-$ResourceGroupName"
    }

    if ($ResourceGroupReport) {
      $StackGroupParameters = @(
        'stack', 'group', 'create',
        '--name', $StackGroupName,
        '--resource-group', $ResourceGroupName,
        '--template-file', $ResourceTemplateFile,
        '--parameters', $ResourceParameterFile,
        '--deny-settings-mode', 'DenyWriteAndDelete',
        '--action-on-unmanage', 'detachAll',
        '--only-show-errors'
      )

      # Deploy Stack
      $Report = az @StackGroupParameters
    }
    else {
      throw "Resource Group Stack deployment failed or returned no results."
    }
  }
  else {
    throw "Resource Group '$ResourceGroupName' does not exist, unable to continue"
  }

  # Create object if report is not null or empty, and optionally publish artifact
  if ($Report) {
    if ($ENV:PUBLISHTESTARTIFACTS) {
      $Report | Out-File -FilePath "$ENV:BUILD_ARTIFACTSTAGINGDIRECTORY/bicep.report.json"
    }
    $ReportObject = $Report | ConvertFrom-Json

    if ($ReportObject.resources) {
      $ReportFiltered = foreach ($ResourceId in $ReportObject.resources.id) {
        $Resource = Get-AzResource -ResourceId $ResourceId -ExpandProperties

        [PSCustomObject]@{
          Name       = $Resource.Name
          Type       = $Resource.ResourceType
          Id         = $Resource.ResourceId
          Location   = $Resource.Location
          Tags       = $Resource.Tags
          Properties = $Resource.Properties
        }
      }
    }
    else {
      Write-Information -InformationAction Continue -MessageData "No resources found in stack '$StackGroupName'."
    }
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
    
    It "should have at least one Tag" -Skip:($ResourceTypeTagExclusion -contains $ResourceType) {

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
        
        # Mapping of flattened design properties to their nested properties in the report
        $PropertyMapping = @{
          # Example of property mapping for specific resource types to nested properties
          # 'ResourceType'         = @{
          #   propertyName        = { param($Resource) $Resource.properties.nestedObject.propertyName }
          # }
          # Example of using a Cmdlet to retrieve properties not returned in AzResource
          # 'ResourceType' = @{
          #   propertyName         = { param($Resource)
          #     $resourceObject = Get-AzCmdlet -ResourceId $Resource.Id
          #     $resourceObject.nestedObject.propertyName # AzResource did not return property
          #   }
          # }
        }

        # Act
        # Skip when the property is disabled for this resource type
        $PropertyValue = $PropertySkipMatrix[$ResourceType]?[$Property.Name]
        $SkipProperty = $PropertyValue ? [bool]::Parse($PropertyValue) : $false

        if ($SkipProperty) {
          Set-ItResult -Skipped -Because "it is not applicable for this test"
        }
        
        # If the property mapping exists for the resource type and property name, use it to extract the property path
        if ($PropertyMapping[$ResourceType]?.ContainsKey($Property.Name)) {
          $ActualValue = & $PropertyMapping[$ResourceType][$Property.Name] $ReportResource
        }
        else {
          $ActualValue = $ReportResource.$($Property.Name)
        }
        
        # Assert
        ($ActualValue | Sort-Object) | Should -Be ($Property.Value | Sort-Object)
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

AfterAll {
  
  If ($ENV:TESTSCLEANUPSTACKAFTERTEST) {
    
    Write-Information -InformationAction Continue -MessageData "Cleanup Stack after tests is enabled"
    
    # Resource Group Stack
    if ($Name) {
      $StackGroupName = "ds-$ResourceGroupName-$Name"
    }
    else {
      $StackGroupName = "ds-$ResourceGroupName"
    }
    
    Write-Information -InformationAction Continue -MessageData "Deployment Stack '$StackGroupName' will be deleted"

    $StackGroupParameters = @(
      'stack', 'group', 'delete',
      '--name', $StackGroupName,
      '--resource-group', $ResourceGroupName,
      '--yes',
      '--action-on-unmanage', 'deleteAll',
      '--only-show-errors'
    )
    
    # Delete Stack
    az @StackGroupParameters

    # Subscription Stack
    $StackSubName = "ds-sub-$ResourceGroupName"

    Write-Information -InformationAction Continue -MessageData "Deployment Stack '$StackSubName' will be deleted"
    Write-Information -InformationAction Continue -MessageData "Resource Group '$ResourceGroupName' will be deleted"

    $StackSubParameters = @(
      'stack', 'sub', 'delete',
      '--name', $StackSubName,
      '--yes',
      '--action-on-unmanage', 'deleteAll',
      '--only-show-errors'
    )
    
    # Delete Stack
    az @StackSubParameters
  }
  else {
    Write-Information -InformationAction Continue -MessageData "Cleanup Stack after tests is disabled, the Stack will need to be cleaned up manually."
  }
}
