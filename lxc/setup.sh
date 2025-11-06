#!/bin/bash
# Anthropic Bridge LXC Setup Script
# This script runs inside the LXC container on first boot

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Anthropic Bridge LXC Setup${NC}"
echo "========================================"

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
apt-get update -qq

# Install Node.js 18
echo -e "${YELLOW}Installing Node.js 18...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt-get install -y \
    curl \
    dumb-init \
    ca-certificates \
    --no-install-recommends

# Create app directory
echo -e "${YELLOW}Creating application directory...${NC}"
mkdir -p /usr/local/anthropic-bridge
cd /usr/local/anthropic-bridge

# Create non-root user
echo -e "${YELLOW}Creating service user...${NC}"
if ! id "anthropicbridge" &>/dev/null; then
    adduser --disabled-password --gecos "" --uid 1001 anthropicbridge || true
fi

# Create necessary directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p /var/log/anthropic-bridge
mkdir -p /etc/anthropic-bridge
mkdir -p /opt/anthropic-bridge

# Set permissions
chown -R anthropicbridge:anthropicbridge /var/log/anthropic-bridge
chown -R anthropicbridge:anthropicbridge /opt/anthropic-bridge
chown -R anthropicbridge:anthropicbridge /usr/local/anthropic-bridge

echo "========================================"
echo -e "${GREEN}✅ System setup complete${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy application files to /opt/anthropic-bridge"
echo "2. Configure OPENROUTER_API_KEY in /etc/anthropic-bridge/.env"
echo "3. Create systemd service or use the entrypoint script"
echo ""
echo "Container is ready for application deployment!"
echo "========================================"
