#!/bin/sh
# Smart Router Entrypoint Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Smart Router Container...${NC}"
echo "========================================"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Warning: .env not found${NC}"
    echo "Please ensure OPENROUTER_API_KEY is set"
    echo "========================================"
else
    echo -e "${GREEN}✓ Environment file found${NC}"
fi

# Validate OPENROUTER_API_KEY
if [ -z "${OPENROUTER_API_KEY}" ]; then
    echo -e "${YELLOW}⚠️  Warning: OPENROUTER_API_KEY not set${NC}"
    echo "The router will start but won't be able to make requests"
    echo "Set OPENROUTER_API_KEY in your environment or .env file"
    echo "========================================"
else
    echo -e "${GREEN}✓ OpenRouter API key configured${NC}"
fi

# Check port
PORT=${PORT:-3000}
echo -e "${GREEN}✓ Port: ${PORT}${NC}"

# Create logs directory
mkdir -p /tmp

echo "========================================"
echo -e "${GREEN}✅ Container initialization complete${NC}"
echo "Starting Smart Router on port ${PORT}..."
echo "========================================"

# Execute the main command
exec "$@"
