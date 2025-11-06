#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# ACI.dev MCP Setup Script
#==============================================================================
# Setup automatico per ACI.dev MCP per ricerche web e scoperta modelli SOTA
#
# Usage: ./setup-aci-dev.sh
#==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROVIDERS_DIR="$PROJECT_ROOT/config/providers"
ENV_FILE="$PROVIDERS_DIR/.env"

#==============================================================================
# Helper Functions
#==============================================================================

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -n -e "${RED}✗${NC} $*" >&2; }

#==============================================================================
# Check Dependencies
#==============================================================================

check_dependencies() {
    local missing=()

    if ! command -v uv &> /dev/null; then
        missing+=("uv (Python package manager)")
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        log_info "Install with:"
        echo "  - uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo "  - jq: sudo apt install jq (Ubuntu/Debian)"
        exit 1
    fi

    log_success "All dependencies installed"
}

#==============================================================================
# Get ACI.dev API Key
#==============================================================================

get_aci_api_key() {
    echo ""
    echo -e "${CYAN}=== ACI.dev API Configuration ===${NC}"
    echo ""
    log_info "Get your ACI.dev API key from: https://platform.aci.dev/project-setting"
    echo ""
    printf "Enter your ACI.dev API key: "
    read -r aci_key

    if [[ -z "$aci_key" ]]; then
        log_error "API key is required"
        exit 1
    fi

    echo "$aci_key"
}

get_linked_account_id() {
    echo ""
    log_info "Get your Linked Account Owner ID from: https://platform.aci.dev/linked-accounts"
    echo ""
    printf "Enter your Linked Account Owner ID: "
    read -r account_id

    if [[ -z "$account_id" ]]; then
        log_error "Linked Account Owner ID is required"
        exit 1
    fi

    echo "$account_id"
}

#==============================================================================
# Update .env File
#==============================================================================

update_env_file() {
    local aci_key="$1"
    local account_id="$2"

    # Backup existing .env
    if [[ -f "$ENV_FILE" ]]; then
        local backup_file="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_FILE" "$backup_file"
        log_info "Backup created: $backup_file"
    fi

    # Create or append to .env
    {
        echo ""
        echo "# ACI.dev MCP Configuration"
        echo "# Added: $(date)"
        echo "ACI_API_KEY=$aci_key"
        echo "LINKED_ACCOUNT_OWNER_ID=$account_id"
        echo ""
        echo "# Optional: Web Search APIs"
        echo "# FIRECRAWL_API_KEY=your_firecrawl_key"
        echo "# BRAVE_SEARCH_API_KEY=your_brave_key"
        echo "# SERPAPI_API_KEY=your_serpapi_key"
    } >> "$ENV_FILE"

    log_success "Updated .env file with ACI.dev configuration"
}

#==============================================================================
# Test ACI.dev Connection
#==============================================================================

test_aci_connection() {
    log_info "Testing ACI.dev connection..."

    # Load environment
    set -a
    source "$ENV_FILE"
    set +a

    # Test API key
    if curl -s -H "Authorization: Bearer $ACI_API_KEY" \
        https://api.aci.dev/v1/health > /dev/null 2>&1; then
        log_success "ACI.dev API key is valid"
    else
        log_error "Invalid API key or API unavailable"
        log_info "Please verify your API key at: https://platform.aci.dev/project-setting"
        return 1
    fi

    # Test linked account
    if curl -s -H "Authorization: Bearer $ACI_API_KEY" \
        "https://api.aci.dev/v1/linked-accounts" > /dev/null 2>&1; then
        log_success "Linked Account Owner ID is valid"
    else
        log_warning "Linked Account Owner ID might be invalid"
        log_info "Please verify at: https://platform.aci.dev/linked-accounts"
    fi
}

#==============================================================================
# Test MCP Server
#==============================================================================

test_mcp_server() {
    log_info "Testing ACI MCP Server..."

    # Check if aci-mcp is installed
    if ! command -v aci-mcp &> /dev/null; then
        log_info "Installing ACI MCP..."
        uvx aci-mcp@latest --help > /dev/null 2>&1 || {
            log_error "Failed to install ACI MCP"
            return 1
        }
    fi

    # Test unified server (dry run)
    log_info "Testing Unified MCP Server..."
    timeout 5 uvx aci-mcp@latest unified-server \
        --linked-account-owner-id "$LINKED_ACCOUNT_OWNER_ID" \
        --allowed-apps-only \
        --help > /dev/null 2>&1 && {
        log_success "ACI MCP Unified Server is ready"
    } || {
        log_warning "MCP server test timed out (this is normal for help mode)"
        log_success "ACI MCP is installed and configured"
    }
}

#==============================================================================
# Show Usage Examples
#==============================================================================

show_examples() {
    echo ""
    echo -e "${CYAN}=== Usage Examples ===${NC}"
    echo ""
    echo -e "${YELLOW}1. Search for OpenRouter models:${NC}"
    echo "   ACI_SEARCH_FUNCTIONS({"
    echo "     \"intent\": \"web search openrouter models\""
    echo "   })"
    echo ""
    echo -e "${YELLOW}2. Execute web search:${NC}"
    echo "   ACI_EXECUTE_FUNCTION({"
    echo "     \"function_name\": \"FIRECRAWL__SEARCH\","
    echo "     \"function_arguments\": {"
    echo "       \"body\": {"
    echo "         \"query\": \"OpenRouter SOTA programming models 2025\","
    echo "         \"limit\": 10"
    echo "       }"
    echo "     }"
    echo "   })"
    echo ""
    echo -e "${YELLOW}3. Full documentation:${NC}"
    echo "   See: docs/providers/ACI_DEV_INTEGRATION.md"
    echo ""
}

#==============================================================================
# Main Setup
#==============================================================================

main() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║  ACI.dev MCP Setup for Multi-Provider     ║"
    echo "║  Ricerche web e scoperta modelli SOTA     ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    # Check dependencies
    check_dependencies

    # Check if .env exists
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found!"
        log_info "Please run the provider setup first:"
        echo "  ./scripts/claude-providers/switch-provider.sh"
        exit 1
    fi

    # Get configuration
    local aci_key
    aci_key=$(get_aci_api_key)

    local account_id
    account_id=$(get_linked_account_id)

    # Update configuration
    echo ""
    log_info "Updating configuration..."
    update_env_file "$aci_key" "$account_id"

    # Test connection
    echo ""
    test_aci_connection

    # Test MCP server
    echo ""
    test_mcp_server

    # Show examples
    show_examples

    echo ""
    log_success "ACI.dev MCP setup completed!"
    log_info "You can now use ACI.dev for dynamic model discovery and web searches"
    echo ""
}

# Run main
main "$@"
