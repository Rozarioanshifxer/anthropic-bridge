#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Test Provider Configuration
#==============================================================================
# Test if a provider configuration is valid and the API is reachable
#
# Usage: ./test-provider.sh <provider-id>
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
PROVIDERS_DIR="$PROJECT_ROOT/config/providers"

#==============================================================================
# Helper Functions
#==============================================================================

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

#==============================================================================
# Test Functions
#==============================================================================

# Test if config file exists and is readable
test_config_file() {
    local provider="$1"
    local config_file="$PROVIDERS_DIR/.env.$provider"

    log_info "Testing configuration file..."

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        log_error "Config file not readable: $config_file"
        return 1
    fi

    log_success "Config file exists and is readable"
    return 0
}

# Load and validate environment variables
test_env_vars() {
    local provider="$1"
    local config_file="$PROVIDERS_DIR/.env.$provider"

    log_info "Loading environment variables..."

    # Load config
    set -a
    # shellcheck disable=SC1090
    source "$config_file" 2>/dev/null || {
        log_error "Failed to source config file"
        return 1
    }
    set +a

    # Check required variables
    local required_vars=(
        "PROVIDER_NAME"
        "PROVIDER_TYPE"
        "ANTHROPIC_BASE_URL"
        "ANTHROPIC_AUTH_TOKEN"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required variables: ${missing_vars[*]}"
        return 1
    fi

    log_success "All required environment variables present"

    # Display loaded config
    echo ""
    echo "Configuration:"
    echo "  Provider: $PROVIDER_NAME ($PROVIDER_TYPE)"
    echo "  Base URL: $ANTHROPIC_BASE_URL"
    echo "  Model: ${ANTHROPIC_MODEL:-not set}"
    echo "  Timeout: ${API_TIMEOUT_MS:-120000}ms"
    echo ""

    return 0
}

# Test API endpoint connectivity
test_api_connectivity() {
    log_info "Testing API connectivity..."

    local url="$ANTHROPIC_BASE_URL"

    # Remove /v1 or /anthropic suffix for base connectivity test
    local base_url="${url%%/v1*}"
    base_url="${base_url%%/anthropic*}"

    if curl -sS --connect-timeout 10 -I "$base_url" >/dev/null 2>&1; then
        log_success "API endpoint is reachable: $base_url"
        return 0
    else
        log_warning "Could not reach base URL: $base_url"
        log_info "This may be normal if the endpoint doesn't respond to HEAD requests"
        return 0
    fi
}

# Test API authentication (simple messages request)
test_api_auth() {
    log_info "Testing API authentication..."

    local url="${ANTHROPIC_BASE_URL}/messages"
    local auth_header="Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}"

    # Simple test request
    local response
    response=$(curl -sS -X POST "$url" \
        -H "$auth_header" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "'"${ANTHROPIC_MODEL:-claude-3-5-sonnet-20241022}"'",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "Hi"}]
        }' 2>&1) || {
        log_error "API request failed"
        echo "$response"
        return 1
    }

    # Check for errors
    if echo "$response" | grep -q '"error"'; then
        log_error "API returned error:"
        echo "$response" | grep '"error"' || echo "$response"
        return 1
    fi

    # Check for success
    if echo "$response" | grep -q '"content"'; then
        log_success "API authentication successful!"
        log_success "Model responded correctly"
        return 0
    fi

    log_warning "Unexpected response:"
    echo "$response"
    return 1
}

#==============================================================================
# Main
#==============================================================================

main() {
    local provider="${1:-}"

    if [[ -z "$provider" ]]; then
        log_error "Usage: $0 <provider-id>"
        echo ""
        echo "Available providers:"
        find "$PROVIDERS_DIR" -name ".env.*.template" -type f | while read -r f; do
            local p
            p=$(basename "$f" .template)
            p="${p#.env.}"
            echo "  - $p"
        done
        exit 1
    fi

    echo ""
    echo "Testing provider: $provider"
    echo "========================================"
    echo ""

    # Run tests
    local failed=0

    test_config_file "$provider" || ((failed++))
    test_env_vars "$provider" || ((failed++))
    test_api_connectivity || ((failed++))
    test_api_auth || ((failed++))

    echo ""
    echo "========================================"

    if [[ $failed -eq 0 ]]; then
        log_success "All tests passed! Provider is ready to use."
        echo ""
        log_info "Switch to this provider:"
        echo "  ./scripts/claude-providers/switch-provider.sh"
        exit 0
    else
        log_error "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
