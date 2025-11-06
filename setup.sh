#!/bin/bash
#
# Anthropic Bridge Setup Script
# Configures initial environment before deployment
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PORT=3000
DEFAULT_NODE_ENV=production

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Anthropic Bridge v1.0 - Initial Configuration        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if .env already exists
if [ -f .env ]; then
    echo -e "${YELLOW}⚠️  Existing .env file found!${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Setup cancelled.${NC}"
        exit 0
    fi
fi

# Collect configuration
echo -e "${BLUE}📝 Configuration Setup${NC}"
echo ""

# API Key
echo -n "Enter your OpenRouter API Key: "
read -s API_KEY
echo
if [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ API Key is required!${NC}"
    exit 1
fi

# Validate API key format
if [[ ! $API_KEY =~ ^sk-or-v1- ]]; then
    echo -e "${YELLOW}⚠️  Warning: API key doesn't start with 'sk-or-v1-'. Proceeding anyway...${NC}"
fi

echo ""

# Port configuration
echo -n "Port for Anthropic Bridge (default: $DEFAULT_PORT): "
read PORT
PORT=${PORT:-$DEFAULT_PORT}

# Validate port
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo -e "${RED}❌ Invalid port number! Using default: $DEFAULT_PORT${NC}"
    PORT=$DEFAULT_PORT
fi

echo ""

# Environment
echo -n "Environment (default: $DEFAULT_NODE_ENV): "
read NODE_ENV
NODE_ENV=${NODE_ENV:-$DEFAULT_NODE_ENV}

echo ""

# Claude Settings Examples
echo -e "${BLUE}🎯 Claude Settings Files${NC}"
echo "The following settings files will be available:"
echo "  • config/glm.json.example    (GLM-4.6 model)"
echo "  • config/gpt-4o.json.example (GPT-4o model)"
echo ""

# Create .env file
echo -e "${BLUE}📝 Creating .env file...${NC}"
cat > .env << EOF
# Anthropic Bridge Configuration
# Generated on: $(date)

# OpenRouter API Key (REQUIRED)
OPENROUTER_API_KEY=$API_KEY

# Server Configuration
PORT=$PORT
NODE_ENV=$NODE_ENV

# For Docker deployments, the port in .env should match docker-compose.yml
# Default docker-compose.yml uses port 3000
EOF

# Set secure permissions
chmod 600 .env

echo -e "${GREEN}✅ Created .env file successfully!${NC}"
echo ""

# Validate API key by testing OpenRouter
echo -e "${BLUE}🔑 Validating API Key with OpenRouter...${NC}"
if command -v curl >/dev/null 2>&1; then
    RESPONSE=$(curl -s -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        https://openrouter.ai/api/v1/models 2>&1)

    if echo "$RESPONSE" | grep -q '"data"'; then
        echo -e "${GREEN}✅ API Key is valid!${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not validate API key. Please verify manually.${NC}"
        echo "Response: $RESPONSE"
    fi
else
    echo -e "${YELLOW}⚠️  curl not found, skipping API validation.${NC}"
fi

echo ""

# Display configuration summary
echo -e "${BLUE}📋 Configuration Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "API Key:    ${GREEN}$(echo $API_KEY | sed 's/./*/g')${NC}"
echo -e "Port:       $PORT"
echo -e "Environment: $NODE_ENV"
echo -e ".env file:  ${GREEN}Created${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Next steps
echo -e "${GREEN}🚀 Next Steps:${NC}"
echo ""
echo -e "${YELLOW}1. Native deployment:${NC}"
echo "   ./scripts/router-control.sh start"
echo ""
echo -e "${YELLOW}2. Docker deployment:${NC}"
echo "   docker-compose up -d"
echo ""
echo -e "${YELLOW}3. Test with Claude:${NC}"
echo "   claude --settings config/glm.json.example -p \"Hello\""
echo ""
echo -e "${YELLOW}4. View logs:${NC}"
echo "   tail -f /tmp/anthropic-bridge.log"
echo ""

# Health check hint
echo -e "${BLUE}💡 Health Check:${NC}"
echo "After starting, verify with: curl http://localhost:$PORT/health"
echo ""

echo -e "${GREEN}✅ Setup completed successfully!${NC}"
