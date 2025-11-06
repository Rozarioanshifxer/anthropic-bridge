#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTER_SCRIPT="$SCRIPT_DIR/../src/anthropic-bridge.js"
PID_FILE="/tmp/anthropic-bridge.pid"
LOG_FILE="/tmp/anthropic-bridge.log"

# Logging functions
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Check if router is running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Start router
start_router() {
    if is_running; then
        log_warning "Router is already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    log_info "Starting Anthropic Bridge..."

    # Make router executable
    chmod +x "$ROUTER_SCRIPT"

    # Load environment variables
    local env_file="$SCRIPT_DIR/../.env"
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
        log_info "Loaded environment from: $env_file"

        # Check for OpenRouter API key
        if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
            log_warning "OPENROUTER_API_KEY not found in $env_file"
        fi
    else
        log_warning "Environment file not found: $env_file"
        log_info "Please create it with your OPENROUTER_API_KEY"
    fi

    # Start in background with environment
    nohup node "$ROUTER_SCRIPT" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 2

    if is_running; then
        log_success "Router started (PID: $pid)"
        log_info "Listening on: http://localhost:3000"
        log_info "Mode: Anthropic → OpenAI Translator for OpenRouter"
        return 0
    else
        log_error "Failed to start router"
        cat "$LOG_FILE"
        return 1
    fi
}

# Stop router
stop_router() {
    if ! is_running; then
        log_warning "Router is not running"
        rm -f "$PID_FILE"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    log_info "Stopping router (PID: $pid)..."

    if kill "$pid" 2>/dev/null; then
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi

    rm -f "$PID_FILE"
    log_success "Router stopped"
}

# Show bridge status
status_router() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Anthropic Bridge Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""

    # Bridge status
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo -e "Bridge: ${GREEN}Running${NC} (PID: $pid)"
        echo "Endpoint: http://localhost:3000"
        echo "Mode: Anthropic → OpenAI Translator"
        echo "Provider: OpenRouter"
    else
        echo -e "Bridge: ${RED}Stopped${NC}"
    fi

    # Test connectivity if running
    if is_running; then
        echo ""
        echo "Testing connectivity..."
        if curl -s http://localhost:3000/health > /dev/null; then
            echo -e "  Health check: ${GREEN}✓ OK${NC}"
        else
            echo -e "  Health check: ${RED}✗ Failed${NC}"
        fi
    fi

    echo ""
}

# Show usage
usage() {
    cat <<EOF
Anthropic Bridge Control - Anthropic to OpenAI Translator

Usage:
  $0 start                          Start the bridge
  $0 stop                           Stop the bridge
  $0 restart                        Restart the bridge
  $0 status                         Show bridge status

Model Selection:
  Models are passed via Claude Code settings files.
  Create settings files in ~/.claude/settings/:
    - glm.json
    - custom-model.json

  Then launch Claude with:
    claude --settings ~/.claude/settings/glm.json

Configuration:
  Create .env with:
    OPENROUTER_API_KEY=your_key_here

Examples:
  $0 start
  $0 status
  $0 stop

During Claude Code session:
  Model is determined by the settings file you pass with --settings

EOF
}

# Main
main() {
    case "${1:-}" in
        start)
            start_router
            ;;
        stop)
            stop_router
            ;;
        restart)
            stop_router
            sleep 1
            start_router
            ;;
        status)
            status_router
            ;;
        ""|help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
