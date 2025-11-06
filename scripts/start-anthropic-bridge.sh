#!/bin/bash
# Start anthropic-bridge service with environment variables
# Usage: ./scripts/start-anthropic-bridge.sh

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    echo "Loading environment from $PROJECT_DIR/.env"
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
else
    echo "Error: .env file not found at $PROJECT_DIR/.env"
    exit 1
fi

# Check API key
if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "Error: OPENROUTER_API_KEY not set in .env"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

# Start service
echo "Starting anthropic-bridge service..."
echo "Service: Anthropic → OpenAI Translator"
echo "Target: OpenRouter"
echo "Port: 3000"
echo ""

node src/anthropic-bridge.js
