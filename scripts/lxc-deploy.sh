#!/bin/bash
# LXC Deployment Script for Proxmox

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CTID=${1:-900}
HOST=${2:-proxmox}
APP_DIR="/opt/anthropic-bridge"

echo -e "${GREEN}🐧 Anthropic Bridge - LXC Deployment Script${NC}"
echo "====================================================="
echo "Container ID: $CTID"
echo "Proxmox Host: $HOST"
echo ""

# Check if CTID is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <CTID> [proxmox-host]${NC}"
    echo "Example: $0 900 proxmox.local"
    exit 1
fi

# Check if container exists
if ! ssh root@$HOST "pct status $CTID" &>/dev/null; then
    echo -e "${RED}❌ Container $CTID not found on $HOST${NC}"
    echo "Creating container..."
    ssh root@$HOST << EOF
pct create $CTID local:vztmpl/ubuntu-22.04-standard_22.07-1_amd64.tar.zst \
  --net0 name=eth0,bridge=vmbr0,ip=YOUR_CONTAINER_IP/24,gw=YOUR_GATEWAY \
  --rootfs local-lvm:2 \
  --unprivileged 1 \
  --features nesting=1 \
  --memory 512 \
  --cores 1 \
  --hostname anthropic-bridge
EOF
fi

# Start container
echo -e "${YELLOW}Starting container...${NC}"
ssh root@$HOST "pct start $CTID"

# Wait for container to be ready
echo -e "${YELLOW}Waiting for container to be ready...${NC}"
sleep 10

# Run setup script
echo -e "${YELLOW}Running setup script...${NC}"
ssh root@$HOST "pct push $CTID lxc/setup.sh /tmp/setup.sh"
ssh root@$HOST "pct set $CTID -script /tmp/setup.sh"
ssh root@$HOST "pct reboot $CTID"

# Wait for setup to complete
echo -e "${YELLOW}Waiting for setup to complete...${NC}"
sleep 30

# Copy application files
echo -e "${YELLOW}Copying application files...${NC}"
ssh root@$HOST "pct push $CTID . $APP_DIR"
ssh root@$HOST "pct push $CTID lxc/anthropic-bridge.service /etc/systemd/system/"

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
ssh root@$HOST "pct set $CTID -permissions $CTID:anthropicbridge:anthropicbridge:$APP_DIR"

# Create environment file if it doesn't exist
echo -e "${YELLOW}Setting up environment...${NC}"
ssh root@$HOST "pct enter $CTID -- bash -c 'cat > /etc/anthropic-bridge/.env << EOF
OPENROUTER_API_KEY=your_api_key_here
EOF'"

# Enable and start service
echo -e "${YELLOW}Enabling and starting service...${NC}"
ssh root@$HOST "pct enter $CTID -- systemctl enable anthropic-bridge"
ssh root@$HOST "pct enter $CTID -- systemctl start anthropic-bridge"

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
sleep 5

if ssh root@$HOST "pct enter $CTID -- systemctl is-active --quiet anthropic-bridge"; then
    echo ""
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo "================================================="
    echo "Container: $CTID"
    echo "IP: YOUR_CONTAINER_IP"
    echo "Port: 3000"
    echo "Service: anthropic-bridge"
    echo ""
    echo "Test with:"
    echo "  curl http://YOUR_CONTAINER_IP:3000/health"
    echo "================================================="
else
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo "Check logs:"
    ssh root@$HOST "pct enter $CTID -- journalctl -u anthropic-bridge -n 50"
    exit 1
fi
