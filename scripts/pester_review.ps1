param(
    [Parameter(Mandatory = $false)]
    [string]$TestsPath = '.',

    [Parameter(Mandatory = $false)]
    [string]$ResultsFile = 'TestResults/pester.review.txt'
)

Write-Information -InformationAction Continue -MessageData "Pester review information"
Write-Information -InformationAction Continue -MessageData "TestsPath: $TestsPath"
Write-Information -InformationAction Continue -MessageData "ResultsFile (deploy run will emit XML to this path): $ResultsFile"

if (-not (Test-Path $TestsPath)) {
    Write-Warning "The supplied TestsPath '$TestsPath' does not exist in the review snapshot."
}

# In review we only surface metadata instead of executing the tests.
Write-Information -InformationAction Continue -MessageData "Skipping test execution because this is a review-only run."
