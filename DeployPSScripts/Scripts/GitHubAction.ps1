param(
  [string]$RepoPath,
  [string]$DeployScriptPath = "DeployPSScripts/Scripts/DeployWeb.ps1",
  [string]$GitHubActionScriptPath = "DeployPSScripts/Scripts/GitHubAction.ps1",
  [string]$CommitMessage = "Add GitHub Actions workflow",
  [string]$BranchName = "main",
  [switch]$Debug,
  [switch]$GitPush
)

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\DeployHelper.psm1")

# Verify the repository path exists
if (-not (Test-Path $RepoPath)) {
  Write-Host "Repository path does not exist: $RepoPath" -ForegroundColor Red
  exit 1
}

# Ensure DeployScriptPath exists
if (-not (Test-Path $DeployScriptPath)) {
  Write-Host "Deploy script path does not exist: $DeployScriptPath" -ForegroundColor Red
  Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
  exit 1
}

# Ensure GitHubActionScriptPath exists
if (-not (Test-Path $GitHubActionScriptPath)) {
  Write-Host "GitHub Action script path does not exist: $GitHubActionScriptPath" -ForegroundColor Red
  exit 1
}

# Use explicit paths for the workflow file
$FullDeployScriptPath = (Resolve-Path $DeployScriptPath).Path
Write-Host "Full Deploy Script Path: $FullDeployScriptPath" -ForegroundColor Cyan

# Get the path relative to the repository root
Push-Location $RepoPath
$RepoRelativeDeployScriptPath = "DeployPSScripts\Scripts\DeployWeb.ps1"
Pop-Location

Write-Host "Repo Relative Deploy Script Path: $RepoRelativeDeployScriptPath" -ForegroundColor Cyan

# Find project folders using the existing logic
$projectFolders = Find-ProjectFolders -StartPath $RepoPath
$frontendFolder = Split-Path $projectFolders.FrontendPath -Leaf
$backendFolder = Split-Path $projectFolders.BackendPath -Leaf

Write-Host "Detected frontend folder: $frontendFolder" -ForegroundColor Green
Write-Host "Detected backend folder: $backendFolder" -ForegroundColor Green

# Create .github/workflows directory if it doesn't exist
$workflowDir = Join-Path -Path $RepoPath -ChildPath ".github/workflows"
if (-not (Test-Path $workflowDir)) {
  New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
}

# Create the deployment workflow file
$workflowContent = @"
name: CI/CD Pipeline

on:
  push:
    branches: [ $BranchName ]

jobs:
  build-and-deploy:
    runs-on: windows-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '20'
    
    - name: Install dependencies
      run: npm install
      working-directory: ./$frontendFolder
    
    - name: Build and deploy
      run: powershell -ExecutionPolicy Bypass -File $RepoRelativeDeployScriptPath -RepoPath `${{ github.workspace }} -CI
    
"@

# Check if deploy.yml exists, create if not
$workflowPath = Join-Path -Path $workflowDir -ChildPath "deploy$BranchName.yml"
if (-not (Test-Path -Path $workflowPath)) {
  New-Item -ItemType File -Path $workflowPath -Force
}

# Write the content to the file
$workflowContent | Out-File -FilePath $workflowPath -Encoding UTF8
Write-Host "GitHub Actions workflow created at: $workflowPath"

# Also, make sure the DeployPSScripts directory exists in the repo
$repoDeployScriptsDir = Join-Path -Path $RepoPath -ChildPath "DeployPSScripts\Scripts"
if (-not (Test-Path $repoDeployScriptsDir)) {
  Write-Host "WARNING: DeployPSScripts\Scripts directory doesn't exist in the repository." -ForegroundColor Yellow
  Write-Host "Creating directory: $repoDeployScriptsDir" -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $repoDeployScriptsDir -Force | Out-Null
  
  # Copy the deploy script to the repo if it's not already there
  $targetDeployScriptPath = Join-Path -Path $repoDeployScriptsDir -ChildPath "DeployWeb.ps1"
  if (-not (Test-Path $targetDeployScriptPath) -and (Test-Path $FullDeployScriptPath)) {
    Write-Host "Copying $FullDeployScriptPath to $targetDeployScriptPath" -ForegroundColor Yellow
    Copy-Item -Path $FullDeployScriptPath -Destination $targetDeployScriptPath -Force
  }
}

# Change to repo directory
Push-Location $RepoPath

# Execute the push
if ($GitPush) {
  Push-ToGitHub -BranchName $BranchName -CommitMessage $CommitMessage -RelativeDeployScriptPath $RepoRelativeDeployScriptPath
}
else {
  Write-Host "Git push is disabled. Skipping push to GitHub." -ForegroundColor Yellow
}

Write-Host "Workflow generation completed." -ForegroundColor Green

# Return to original directory
Pop-Location