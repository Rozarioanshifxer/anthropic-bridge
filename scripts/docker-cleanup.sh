#!/bin/bash
# Docker Cleanup Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

IMAGE_NAME="anthropic-bridge"

echo -e "${YELLOW}🧹 Docker Cleanup Script${NC}"
echo "=========================================="

# Stop and remove containers
echo -e "${YELLOW}Stopping containers...${NC}"
docker-compose down 2>/dev/null || true
docker stop ${IMAGE_NAME} 2>/dev/null || true
docker rm ${IMAGE_NAME} 2>/dev/null || true

# Remove images
echo -e "${YELLOW}Removing images...${NC}"
docker rmi ${IMAGE_NAME}:latest 2>/dev/null || true
docker rmi ${IMAGE_NAME}:1.0 2>/dev/null || true

# Remove dangling images
echo -e "${YELLOW}Removing dangling images...${NC}"
docker image prune -f

# Remove unused volumes
echo -e "${YELLOW}Removing unused volumes...${NC}"
docker volume prune -f

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo "=========================================="
echo "Remaining images:"
docker images | grep ${IMAGE_NAME} || echo "  No anthropic-bridge images found"
echo "=========================================="
