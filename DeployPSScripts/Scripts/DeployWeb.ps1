param(
    [switch]$Debug,
    [string]$RepoPath = $null,
    [switch]$Dev,
    [switch]$CI # New parameter to indicate CI environment
)

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\DeployHelper.psm1")

if ($Debug) { $DebugPreference = 'Continue' }

Write-Debug "Current Directory: $pwd"
if ($null -eq $RepoPath) {
    Write-Host "Please provide the path to the web project directory." -ForegroundColor Red
    Write-Host "Example: .\DeployWeb.ps1 -RepoPath 'C:\Projects\Sample-MERN-Project'" -ForegroundColor Red
    exit 1
}

try {
    # Find project folders
    $projectFolders = Find-ProjectFolders -StartPath $RepoPath

    # Use discovered paths
    $RepoPath = $projectFolders.ProjectRoot
    $frontendPath = $projectFolders.FrontendPath
    $backendPath = $projectFolders.BackendPath

    Push-Location -Path $RepoPath

    # Only modify PATH in local environment
    if (-not $CI) {
        $nodePath = "C:\Program Files\nodejs"
        if (-not ($env:Path -split ";" -contains $nodePath)) {
            $env:Path += ";$nodePath"
            Write-Debug "Environment path: $env:Path"
            Write-Host "Added Node.js to the PATH for this session."
        }
    }

    # Step 1: Check if MongoDB is running (skip in CI)
    if (-not $CI) {
        Write-Host "Checking if MongoDB is running..."
        $mongoProcess = Get-Process -Name "mongod" -ErrorAction SilentlyContinue
        Write-Debug "MongoDB process: $mongoProcess"

        if ($mongoProcess) {
            Write-Host "MongoDB is already running."
        }
        else {
            # Simple MongoDB path check
            $mongoDbPath = "\mongodb\data"
            if (-not (Test-Path $mongoDbPath)) {
                New-Item -Path $mongoDbPath -ItemType Directory -Force | Out-Null
                Write-Host "Created MongoDB data directory: $mongoDbPath"
            }
            
            Write-Host "Starting MongoDB..."
            Start-Process -FilePath "mongod" -ArgumentList "--dbpath=$mongoDbPath" -NoNewWindow
            Start-Sleep -Seconds 5
        }
    }

    # Step 2: Build the React app
    Write-Host "Building the React app..."
    Set-Location -Path $frontendPath
    Write-Debug "Current Directory: $pwd"
    npm install
    npm run build

    # Only start servers in local environment
    if (-not $CI) {
        # Step 3: Start the backend server
        Write-Host "Starting the backend server..."
        Set-Location -Path $backendPath
        Write-Debug "Current Directory: $pwd"
        npm install

        # Dynamic server file detection - assumes one of the common server files exists
        $serverFiles = @("server.js", "app.js", "index.js", "main.js")
        $serverFile = $serverFiles | Where-Object { Test-Path $_ } | Select-Object -First 1

        if (-not $serverFile) {
            throw "No server entry file found (tried: $($serverFiles -join ', '))"
        }

        Write-Host "Launching backend using: $serverFile" -ForegroundColor Green
        Start-Process -FilePath "node" -ArgumentList $serverFile -NoNewWindow -PassThru

        # Step 4: Start the frontend development server with fallback
        Write-Host "Starting the frontend server..."
        Set-Location -Path $frontendPath
        Write-Debug "Current Directory: $pwd"
        
        # If Dev switch is set, use 'npm run dev' for development mode
        # Otherwise, use 'npm start' for production mode
        $startCommand = "start"
        if ($Dev) {
            Write-Host "Development mode enabled. Using 'npm run dev'."
            $startCommand = "dev"
        }
        else {
            Write-Host "Production mode enabled. Using 'npm start'."
            $startCommand = "start"
        }
        
        Write-Host "Starting frontend with 'npm run $startCommand'..."
        npm run $startCommand

        Write-Host "Deployment complete!"
        Write-Host "Access the backend at: http://localhost:5000"
        Write-Host "Access the frontend at: http://localhost:5173 or http://localhost:3000"
    }
    else {
        Write-Host "CI deployment completed successfully!"
    }
}
catch {
    Write-Error "An error occurred during deployment: $_"
    exit 1
}
finally {
    Pop-Location
    Write-Host "Script execution finished."
}