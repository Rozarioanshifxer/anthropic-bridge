#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Anthropic Proxy Lifecycle Manager
#==============================================================================
# Manages anthropic-proxy lifecycle for OpenRouter integration
#
# Usage: ./proxy-lifecycle.sh {start|stop|status|restart}
#==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
PID_FILE="/tmp/anthropic-proxy.pid"
LOG_FILE="/tmp/anthropic-proxy.log"

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

#==============================================================================
# Proxy Management
#==============================================================================

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

start_proxy() {
    if is_running; then
        log_warning "Proxy is already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found: $ENV_FILE"
        return 1
    fi

    log_info "Starting anthropic-proxy..."

    # Load environment
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a

    # Set proxy configuration
    export OPENROUTER_API_KEY
    export REASONING_MODEL="anthropic/claude-sonnet-4"
    export COMPLETION_MODEL="anthropic/claude-3.5-haiku"

    # Start proxy in background
    nohup npx anthropic-proxy > "$LOG_FILE" 2>&1 &
    local pid=$!

    # Save PID
    echo "$pid" > "$PID_FILE"

    # Wait for startup
    sleep 3

    # Verify it started
    if is_running; then
        log_success "Proxy started successfully (PID: $pid)"
        log_info "Listening on: http://localhost:3000"
        log_info "Logs: $LOG_FILE"
        return 0
    else
        log_error "Failed to start proxy"
        cat "$LOG_FILE"
        return 1
    fi
}

stop_proxy() {
    if ! is_running; then
        log_warning "Proxy is not running"
        rm -f "$PID_FILE"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")

    log_info "Stopping proxy (PID: $pid)..."

    # Try graceful shutdown first
    if kill "$pid" 2>/dev/null; then
        sleep 2

        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Graceful shutdown failed, forcing..."
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi

    # Clean up
    rm -f "$PID_FILE"

    # Also kill any other anthropic-proxy processes
    pkill -f "anthropic-proxy" 2>/dev/null || true

    log_success "Proxy stopped"
}

status_proxy() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Anthropic Proxy Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""

    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo -e "Status: ${GREEN}Running${NC}"
        echo "PID: $pid"
        echo "Endpoint: http://localhost:3000"
        echo "Log file: $LOG_FILE"

        # Show recent logs
        if [[ -f "$LOG_FILE" ]]; then
            echo ""
            echo "Recent logs:"
            tail -5 "$LOG_FILE" | sed 's/^/  /'
        fi
    else
        echo -e "Status: ${RED}Stopped${NC}"
        if [[ -f "$PID_FILE" ]]; then
            echo "(Stale PID file found)"
        fi
    fi

    echo ""
}

restart_proxy() {
    log_info "Restarting proxy..."
    stop_proxy
    sleep 1
    start_proxy
}

#==============================================================================
# Main
#==============================================================================

main() {
    local command="${1:-status}"

    case "$command" in
        start)
            start_proxy
            ;;
        stop)
            stop_proxy
            ;;
        status)
            status_proxy
            ;;
        restart)
            restart_proxy
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            exit 1
            ;;
    esac
}

main "$@"
