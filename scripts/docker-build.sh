#!/bin/bash
# Docker Build and Deploy Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

IMAGE_NAME="anthropic-bridge"
VERSION="1.0"

echo -e "${GREEN}🐳 Anthropic Bridge - Docker Build Script${NC}"
echo "============================================"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Warning: .env not found${NC}"
    echo "Copying template..."
    cp .env.example .env
    echo -e "${YELLOW}Please edit .env with your API key${NC}"
    echo ""
fi

# Build image
echo -e "${YELLOW}Building Docker image: ${IMAGE_NAME}:${VERSION}${NC}"
docker build -t ${IMAGE_NAME}:${VERSION} .

# Tag as latest
echo -e "${YELLOW}Tagging as latest${NC}"
docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest

echo ""
echo -e "${GREEN}✅ Build complete!${NC}"
echo "=========================================="
echo "Image: ${IMAGE_NAME}:${VERSION}"
echo "Size: $(docker images ${IMAGE_NAME}:${VERSION} --format '{{.Size}}')"
echo ""
echo "Run with:"
echo "  docker run -d --name anthropic-bridge -p 3000:3000 --env-file .env ${IMAGE_NAME}:${VERSION}"
echo ""
echo "Or use docker-compose:"
echo "  docker-compose up -d"
echo "============================================"
