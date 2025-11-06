#
# Anthropic Bridge - Deploy Script (Windows PowerShell)
# Supports: Docker, LXC, and Native deployment scenarios
#

[CmdletBinding()]
param(
    [string]$DeploymentType = "",
    [string]$ProxmoxHost = "proxmox",
    [int]$CTID = 900
)

# Colors
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$BLUE = "Cyan"
$CYAN = "Cyan"
$NC = "White"

# Global variables
$Global:LOG_FILE = "C:\temp\anthropic-bridge-deploy.log"

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    Add-Content -Path $LOG_FILE -Value $logEntry -Encoding UTF8

    switch ($Level) {
        "INFO"  { Write-Host "ℹ $Message" -ForegroundColor $BLUE }
        "SUCCESS" { Write-Host "✓ $Message" -ForegroundColor $GREEN }
        "WARNING" { Write-Host "⚠ $Message" -ForegroundColor $YELLOW }
        "ERROR" { Write-Host "✗ $Message" -ForegroundColor $RED }
    }
}

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $CYAN
    Write-Host "║       Anthropic Bridge - Deployment Script v1.0          ║" -ForegroundColor $CYAN
    Write-Host "║                                                            ║" -ForegroundColor $CYAN
    Write-Host "║  Deploy Anthropic → OpenAI Translation Bridge             ║" -ForegroundColor $CYAN
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $CYAN
    Write-Host ""
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."

    # Check if .env exists
    if (-not (Test-Path ".env")) {
        Write-Log ".env file not found!" "WARNING"
        Write-Log "Running setup script to create it..." "INFO"

        if (Test-Path "setup.ps1") {
            & .\setup.ps1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Setup script failed!" "ERROR"
                exit 1
            }
        } else {
            Write-Log "setup.ps1 not found! Please create .env manually." "ERROR"
            exit 1
        }
    }

    # Load environment variables
    Get-Content .env | Where-Object { $_ -notmatch "^#" -and $_ -match "=" } | ForEach-Object {
        $parts = $_ -split "=", 2
        Set-Variable -Name $parts[0].Trim() -Value $parts[1].Trim() -Scope Global
    }

    # Check API key
    if ([string]::IsNullOrEmpty($env:OPENROUTER_API_KEY)) {
        Write-Log "OPENROUTER_API_KEY not found in .env file!" "ERROR"
        exit 1
    }

    Write-Log "Prerequisites check passed" "SUCCESS"
    Write-Host ""
}

function Deploy-Docker {
    Write-Log "Deploying with Docker..."

    # Check if Docker is installed
    try {
        $dockerVersion = docker --version 2>$null
        if ([string]::IsNullOrEmpty($dockerVersion)) {
            throw "Docker not found"
        }
        Write-Log "Docker found: $dockerVersion" "INFO"
    } catch {
        Write-Log "Docker is not installed!" "ERROR"
        exit 1
    }

    # Check if docker-compose is available
    try {
        $composeVersion = docker-compose --version 2>$null
        if ([string]::IsNullOrEmpty($composeVersion)) {
            throw "docker-compose not found"
        }
        Write-Log "docker-compose found: $composeVersion" "INFO"
    } catch {
        Write-Log "docker-compose is not installed!" "ERROR"
        exit 1
    }

    # Build image
    Write-Log "Building Docker image..." "INFO"
    docker build -t anthropic-bridge .

    # Start containers
    Write-Log "Starting containers..." "INFO"
    docker-compose up -d

    # Wait for service
    Write-Log "Waiting for service to be ready..." "INFO"
    Start-Sleep -Seconds 5

    # Test endpoint
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Log "Docker deployment successful!" "SUCCESS"
            Write-Host ""
            Write-Host "✅ Service is running at: http://localhost:3000" -ForegroundColor $GREEN
            Write-Host "✅ Health check: http://localhost:3000/health" -ForegroundColor $GREEN
            Write-Host "✅ Status: http://localhost:3000/status" -ForegroundColor $GREEN
            return $true
        }
    } catch {
        Write-Log "Service health check failed!" "ERROR"
        Write-Log "View logs: docker-compose logs anthropic-bridge" "INFO"
        return $false
    }
}

function Deploy-Native {
    Write-Log "Deploying natively..."

    # Check Node.js
    try {
        $nodeVersion = node --version 2>$null
        if ([string]::IsNullOrEmpty($nodeVersion)) {
            throw "Node.js not found"
        }
        Write-Log "Node.js found: $nodeVersion" "INFO"
    } catch {
        Write-Log "Node.js is not installed!" "ERROR"
        exit 1
    }

    # Check npm
    try {
        $npmVersion = npm --version 2>$null
        if ([string]::IsNullOrEmpty($npmVersion)) {
            throw "npm not found"
        }
        Write-Log "npm found: $npmVersion" "INFO"
    } catch {
        Write-Log "npm is not installed!" "ERROR"
        exit 1
    }

    # Install dependencies
    Write-Log "Installing dependencies..." "INFO"
    npm install

    # Start service
    Write-Log "Starting service..." "INFO"
    if (Test-Path "scripts\router-control.sh") {
        bash .\scripts\router-control.sh start
    } else {
        Write-Log "router-control.sh not found, starting directly..." "WARNING"
        node src\anthropic-bridge.js &
    }

    # Wait for service
    Start-Sleep -Seconds 3

    # Test
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Log "Native deployment successful!" "SUCCESS"
            Write-Host ""
            Write-Host "✅ Service is running at: http://localhost:3000" -ForegroundColor $GREEN
            Write-Host "✅ Logs: C:\temp\anthropic-bridge.log" -ForegroundColor $GREEN
            return $true
        }
    } catch {
        Write-Log "Service health check failed!" "ERROR"
        Write-Log "View logs: Get-Content C:\temp\anthropic-bridge.log -Wait" "INFO"
        return $false
    }
}

function Deploy-LXC {
    Write-Log "Deploying to LXC container..." "INFO"

    # Check SSH
    try {
        $sshVersion = ssh -V 2>$null
        Write-Log "SSH found: $sshVersion" "INFO"
    } catch {
        Write-Log "SSH is not installed!" "ERROR"
        exit 1
    }

    # Run deployment script
    if (Test-Path "scripts\lxc-deploy.sh") {
        Write-Log "Running LXC deployment script..." "INFO"
        bash .\scripts\lxc-deploy.sh $CTID $ProxmoxHost
    } else {
        Write-Log "lxc-deploy.sh not found!" "ERROR"
        exit 1
    }

    Write-Log "LXC deployment completed!" "SUCCESS"
    Write-Host ""
    Write-Host "✅ Container: $CTID" -ForegroundColor $GREEN
    Write-Host "✅ Service: anthropic-bridge" -ForegroundColor $GREEN
    Write-Host "✅ Access via container IP:3000" -ForegroundColor $GREEN
}

function Show-MainMenu {
    Write-Banner
    Write-Host "Select deployment scenario:" -ForegroundColor $CYAN
    Write-Host ""
    Write-Host "1) Docker (Recommended for local testing)" -ForegroundColor $CYAN
    Write-Host "2) LXC Container (Proxmox)" -ForegroundColor $CYAN
    Write-Host "3) Native (Direct on host)" -ForegroundColor $CYAN
    Write-Host "4) Exit" -ForegroundColor $CYAN
    Write-Host ""
    $choice = Read-Host "Enter your choice [1-4]"

    # Validate input
    if ($choice -notmatch "^[1-4]$") {
        Write-Log "Invalid choice! Please select 1-4" "ERROR"
        Start-Sleep 2
        return Show-MainMenu
    }

    return $choice
}

function Show-ErrorMenu {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor $RED
    Write-Host ""
    Write-Host "What would you like to do?" -ForegroundColor $CYAN
    Write-Host "1) Retry" -ForegroundColor $CYAN
    Write-Host "2) Back to menu" -ForegroundColor $CYAN
    Write-Host "3) Exit" -ForegroundColor $CYAN
    Write-Host ""
    $choice = Read-Host "Enter your choice [1-3]"

    if ($choice -notmatch "^[1-3]$") {
        Write-Log "Invalid choice!" "ERROR"
        Start-Sleep 1
        return Show-ErrorMenu
    }

    return $choice
}

function Show-Completion {
    param([string]$DeploymentType)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor $GREEN
    Write-Host "🎉 Deployment completed successfully!" -ForegroundColor $GREEN
    Write-Host "========================================" -ForegroundColor $GREEN
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor $CYAN
    Write-Host "1. Test the API: curl http://localhost:3000/health"
    Write-Host "2. View status: curl http://localhost:3000/status"
    Write-Host "3. Test with Claude using settings files in config/"
    Write-Host ""
    Write-Host "Management:" -ForegroundColor $CYAN

    switch ($DeploymentType) {
        "docker" {
            Write-Host "  Start:   docker-compose up -d"
            Write-Host "  Stop:    docker-compose down"
            Write-Host "  Logs:    docker-compose logs -f anthropic-bridge"
            Write-Host "  Status:  docker-compose ps"
        }
        "lxc" {
            Write-Host "  Enter:   pct enter $CTID"
            Write-Host "  Status:  pct status $CTID"
            Write-Host "  Logs:    pct enter $CTID -- journalctl -u anthropic-bridge -f"
        }
        "native" {
            Write-Host "  Start:   .\scripts\router-control.sh start"
            Write-Host "  Stop:    .\scripts\router-control.sh stop"
            Write-Host "  Status:  .\scripts\router-control.sh status"
            Write-Host "  Logs:    Get-Content C:\temp\anthropic-bridge.log -Wait"
        }
    }

    Write-Host ""
    Write-Host "Log file: $LOG_FILE" -ForegroundColor $GREEN
    Write-Host ""
}

function Main {
    # Start logging
    "Deployment started at: $(Get-Date)" | Out-File -FilePath $LOG_FILE -Encoding UTF8

    # Create temp directory if it doesn't exist
    $tempDir = Split-Path $LOG_FILE -Parent
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    # If deployment type is specified via parameter
    if ($DeploymentType) {
        Write-Log "Selected deployment type: $DeploymentType" "INFO"
        Test-Prerequisites

        switch ($DeploymentType) {
            "docker" { $result = Deploy-Docker }
            "lxc" { Deploy-LXC; Show-Completion $DeploymentType; return }
            "native" { $result = Deploy-Native }
            default {
                Write-Log "Invalid deployment type: $DeploymentType" "ERROR"
                Write-Host "Usage: .\deploy.ps1 [docker|lxc|native]" -ForegroundColor $YELLOW
                exit 1
            }
        }

        if ($result) {
            Show-Completion $DeploymentType
        } else {
            exit 1
        }
    } else {
        # Interactive mode with loop
        do {
            $choice = Show-MainMenu

            switch ($choice) {
                "1" { $DeploymentType = "docker" }
                "2" { $DeploymentType = "lxc" }
                "3" { $DeploymentType = "native" }
                "4" { Write-Log "Deployment cancelled." "INFO"; exit 0 }
            }

            if ($choice -match "^[1-3]$") {
                Write-Log "Selected deployment type: $DeploymentType" "INFO"
                Write-Host ""
                Test-Prerequisites

                switch ($DeploymentType) {
                    "docker" { $result = Deploy-Docker }
                    "lxc" { Deploy-LXC; Show-Completion $DeploymentType; return }
                    "native" { $result = Deploy-Native }
                }

                if ($result) {
                    Show-Completion $DeploymentType
                    $success = $true
                } else {
                    $errorChoice = Show-ErrorMenu
                    switch ($errorChoice) {
                        "1" {  # Retry
                            Write-Log "Retrying deployment..." "INFO"
                            $success = $false
                        }
                        "2" {  # Back to menu
                            Write-Log "Returning to main menu..." "INFO"
                            $success = $false
                        }
                        "3" {  # Exit
                            Write-Host ""
                            Write-Log "Deployment failed! Check logs at: $LOG_FILE" "ERROR"
                            Write-Host ""
                            Write-Host "For cleanup:" -ForegroundColor $YELLOW
                            Write-Host "  Docker: docker-compose down" -ForegroundColor $YELLOW
                            Write-Host "  Native: .\scripts\router-control.sh stop" -ForegroundColor $YELLOW
                            exit 1
                        }
                    }
                }
            }
        } while (-not $success)
    }
}

# Run main function
Main
