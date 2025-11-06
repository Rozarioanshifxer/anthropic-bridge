#
# Anthropic Bridge Setup Script (PowerShell)
# Configures initial environment before deployment
#

param(
    [string]$ApiKey,
    [int]$Port = 3000,
    [string]$Environment = "production"
)

# Colors for output
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$BLUE = "Cyan"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $BLUE
Write-Host "║     Anthropic Bridge v1.0 - Initial Configuration        ║"
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $BLUE
Write-Host ""

# Check if .env already exists
if (Test-Path ".env") {
    Write-Host "⚠️  Existing .env file found!" -ForegroundColor $YELLOW
    $response = Read-Host "Do you want to overwrite it? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Setup cancelled." -ForegroundColor $BLUE
        exit 0
    }
}

# Collect configuration
Write-Host "📝 Configuration Setup" -ForegroundColor $BLUE
Write-Host ""

# API Key
if (-not $ApiKey) {
    $secureApiKey = Read-Host "Enter your OpenRouter API Key" -AsSecureString
    $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiKey))
}

if ([string]::IsNullOrEmpty($ApiKey)) {
    Write-Host "❌ API Key is required!" -ForegroundColor $RED
    exit 1
}

# Validate API key format
if ($ApiKey -notmatch "^sk-or-v1-") {
    Write-Host "⚠️  Warning: API key doesn't start with 'sk-or-v1-'. Proceeding anyway..." -ForegroundColor $YELLOW
}

Write-Host ""

# Port configuration
Write-Host "Port for Anthropic Bridge (default: $Port): " -NoNewline -ForegroundColor $BLUE
$portInput = Read-Host
if (-not [string]::IsNullOrEmpty($portInput)) {
    if ($portInput -match "^[0-9]+$" -and [int]$portInput -gt 0 -and [int]$portInput -le 65535) {
        $Port = [int]$portInput
    } else {
        Write-Host "Invalid port number! Using default: $Port" -ForegroundColor $YELLOW
    }
}

Write-Host ""

# Environment
Write-Host "Environment (default: $Environment): " -NoNewline -ForegroundColor $BLUE
$envInput = Read-Host
if (-not [string]::IsNullOrEmpty($envInput)) {
    $Environment = $envInput
}

Write-Host ""

# Claude Settings Examples
Write-Host "🎯 Claude Settings Files" -ForegroundColor $BLUE
Write-Host "The following settings files will be available:"
Write-Host "  • config/glm.json.example    (GLM-4.6 model)"
Write-Host "  • config/gpt-4o.json.example (GPT-4o model)"
Write-Host ""

# Create .env file
Write-Host "📝 Creating .env file..." -ForegroundColor $BLUE

$envContent = @"
# Anthropic Bridge Configuration
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# OpenRouter API Key (REQUIRED)
OPENROUTER_API_KEY=$ApiKey

# Server Configuration
PORT=$Port
NODE_ENV=$Environment

# For Docker deployments, the port in .env should match docker-compose.yml
# Default docker-compose.yml uses port 3000
"@

$envContent | Out-File -FilePath ".env" -Encoding UTF8

# Set secure permissions (Windows equivalent)
try {
    icacls .env /inheritance:r /grant:r "$env:USERNAME`:F" 2>$null
} catch {
    Write-Host "Note: Could not set file permissions (Windows)" -ForegroundColor $YELLOW
}

Write-Host "✅ Created .env file successfully!" -ForegroundColor $GREEN
Write-Host ""

# Validate API key by testing OpenRouter
Write-Host "🔑 Validating API Key with OpenRouter..." -ForegroundColor $BLUE
try {
    $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/models" -Headers @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    } -Method Get -TimeoutSec 10

    if ($response.data) {
        Write-Host "✅ API Key is valid!" -ForegroundColor $GREEN
    } else {
        Write-Host "⚠️  Could not validate API key. Please verify manually." -ForegroundColor $YELLOW
    }
} catch {
    Write-Host "⚠️  Could not validate API key. Please verify manually." -ForegroundColor $YELLOW
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor $YELLOW
}

Write-Host ""

# Display configuration summary
Write-Host "📋 Configuration Summary" -ForegroundColor $BLUE
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "API Key:    " -NoNewline -ForegroundColor $GREEN
Write-Host "$('*' * ($ApiKey.Length - 4) + $ApiKey.Substring($ApiKey.Length - 4))"
Write-Host "Port:       $Port"
Write-Host "Environment: $Environment"
Write-Host ".env file:  " -NoNewline -ForegroundColor $GREEN
Write-Host "Created"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

# Next steps
Write-Host "🚀 Next Steps:" -ForegroundColor $GREEN
Write-Host ""
Write-Host "1. Native deployment:" -ForegroundColor $YELLOW
Write-Host "   .\scripts\router-control.sh start"
Write-Host ""
Write-Host "2. Docker deployment:" -ForegroundColor $YELLOW
Write-Host "   docker-compose up -d"
Write-Host ""
Write-Host "3. Test with Claude:" -ForegroundColor $YELLOW
Write-Host "   claude --settings config\glm.json.example -p `"Hello`""
Write-Host ""
Write-Host "4. View logs:" -ForegroundColor $YELLOW
Write-Host "   Get-Content C:\temp\anthropic-bridge.log -Wait"
Write-Host ""

# Health check hint
Write-Host "💡 Health Check:" -ForegroundColor $BLUE
Write-Host "After starting, verify with: curl http://localhost:$Port/health"
Write-Host ""

Write-Host "✅ Setup completed successfully!" -ForegroundColor $GREEN
Write-Host ""
