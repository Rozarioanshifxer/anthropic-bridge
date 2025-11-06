# Anthropic Bridge Docker Image
FROM node:18-alpine

# Metadata
LABEL maintainer="Marco Del Pin <marco.delpin@gmail.com>"
LABEL description="Anthropic to OpenAI Translator for OpenRouter"
LABEL version="1.0"

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init curl

# Create app directory
WORKDIR /usr/src/anthropic-bridge

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --only=production

# Copy application code
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY config/ ./config/

# Make scripts executable
RUN chmod +x scripts/*.sh

# Create non-root user
RUN addgroup -g 1001 -S anthropicbridge && \
    adduser -S -D -H -u 1001 -h /usr/src/anthropic-bridge -s /sbin/nologin -G anthropicbridge -g anthropicbridge anthropicbridge

# Create logs directory
RUN mkdir -p /tmp && chown -R anthropicbridge:anthropicbridge /tmp

# Switch to non-root user
USER anthropicbridge

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the bridge
CMD ["node", "src/anthropic-bridge.js"]
