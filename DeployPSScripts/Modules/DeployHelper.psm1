<# Helper Module for Deployment Scripts

This module contains helper functions for deployment scripts.  
#>



# Function to find project folders
function Find-ProjectFolders {
    param(
        [string]$StartPath
    )

    # Common frontend folder names (order indicates priority)
    $frontendNames = @('frontend', 'client', 'web', 'app', 'ui')
    
    # Common backend folder names (order indicates priority)
    $backendNames = @('backend', 'server', 'api', 'service')

    # Find first matching frontend folder
    $frontendPath = $frontendNames | ForEach-Object {
        Get-ChildItem -Path $StartPath -Directory -Recurse -Filter $_ -ErrorAction SilentlyContinue | 
        Select-Object -First 1 -ExpandProperty FullName
    } | Where-Object { $_ } | Select-Object -First 1

    # Find first matching backend folder
    $backendPath = $backendNames | ForEach-Object {
        Get-ChildItem -Path $StartPath -Directory -Recurse -Filter $_ -ErrorAction SilentlyContinue | 
        Select-Object -First 1 -ExpandProperty FullName
    } | Where-Object { $_ } | Select-Object -First 1

    if (-not $frontendPath) {
        Write-Host "Could not find frontend folder (tried: $($frontendNames -join ', '))" -ForegroundColor Red
        exit 1
    }

    if (-not $backendPath) {
        Write-Host "Could not find backend folder (tried: $($backendNames -join ', '))" -ForegroundColor Red
        exit 1
    }

    Write-Host "Found frontend at: $frontendPath" -ForegroundColor Green
    Write-Host "Found backend at: $backendPath" -ForegroundColor Green

    return @{
        FrontendPath = $frontendPath
        BackendPath  = $backendPath
        ProjectRoot  = Split-Path $frontendPath -Parent
    }
}


# Git Authentication and Push Function
function Push-ToGitHub {
    param(
        [string]$BranchName,
        [string]$CommitMessage,
        [string]$RelativeDeployScriptPath
    )

    try {

        # Check if the workflow file exists and is not tracked
        $workflowFilePath = ".github/workflows/deploy$BranchName.yml"
        if (Test-Path $workflowFilePath) {
            $gitStatus = git status --porcelain $workflowFilePath
            git add -f $workflowFilePath
        }

        # Commit changes
        git commit -m $CommitMessage

        # Push to repository
        git push origin $BranchName

        Write-Host "Successfully pushed workflow to repository, branch $BranchName" -ForegroundColor Green
    }
    catch {
        Write-Host "Error during git push: $_" -ForegroundColor Red
        exit 1
    }
}