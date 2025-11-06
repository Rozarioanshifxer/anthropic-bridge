#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Claude Code Provider Switcher v2.0
#==============================================================================
# Interactive script to switch between AI providers using a single .env file
# and JSON metadata configuration
#
# Usage: ./switch-provider.sh
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
PROVIDERS_JSON="$PROVIDERS_DIR/providers.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CURRENT_PROVIDER_FILE="$PROVIDERS_DIR/.current-provider"
PROXY_SCRIPT="$SCRIPT_DIR/proxy-lifecycle.sh"

#==============================================================================
# Helper Functions
#==============================================================================

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

#==============================================================================
# Check Dependencies
#==============================================================================

check_dependencies() {
    local missing=()

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install ${missing[*]}"
        exit 1
    fi
}

#==============================================================================
# Provider Discovery
#==============================================================================

get_available_providers() {
    if [[ ! -f "$PROVIDERS_JSON" ]]; then
        log_error "providers.json not found: $PROVIDERS_JSON"
        exit 1
    fi

    # Use keys_unsorted to maintain insertion order in JSON
    jq -r '.providers | keys[]' "$PROVIDERS_JSON"
}

get_current_provider() {
    if [[ -f "$CURRENT_PROVIDER_FILE" ]]; then
        cat "$CURRENT_PROVIDER_FILE"
    else
        echo "anthropic"
    fi
}

set_current_provider() {
    local provider="$1"
    echo "$provider" > "$CURRENT_PROVIDER_FILE"
}

#==============================================================================
# Provider Info
#==============================================================================

get_provider_name() {
    local provider="$1"
    jq -r ".providers.\"$provider\".name" "$PROVIDERS_JSON"
}

get_provider_description() {
    local provider="$1"
    jq -r ".providers.\"$provider\".description" "$PROVIDERS_JSON"
}

get_provider_endpoint() {
    local provider="$1"
    jq -r ".providers.\"$provider\".endpoint" "$PROVIDERS_JSON"
}

has_proxy() {
    local provider="$1"
    local enabled
    enabled=$(jq -r ".providers.\"$provider\".proxy.enabled // false" "$PROVIDERS_JSON")
    [[ "$enabled" == "true" ]]
}

#==============================================================================
# Proxy Management
#==============================================================================

manage_proxy() {
    local provider="$1"
    local current_provider
    current_provider=$(get_current_provider)

    # Stop proxy if current provider uses it (and we're switching away)
    if [[ "$current_provider" != "$provider" ]] && has_proxy "$current_provider"; then
        log_info "Stopping proxy for previous provider..."
        "$PROXY_SCRIPT" stop || true
    fi

    # Start proxy if new provider needs it
    if has_proxy "$provider"; then
        log_info "Starting proxy for OpenRouter..."
        if ! "$PROXY_SCRIPT" start; then
            log_error "Failed to start proxy"
            return 1
        fi
        log_success "Proxy started successfully"
    fi
}

#==============================================================================
# Environment Loading
#==============================================================================

load_env_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found: $ENV_FILE"
        log_info "Copy .env.template to .env and configure your credentials"
        exit 1
    fi

    # Export all variables from .env
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
}

# Expand environment variables in a string
expand_vars() {
    local str="$1"
    # Simple variable expansion (handles ${VAR} format)
    eval "echo \"$str\""
}

#==============================================================================
# Claude Settings Management
#==============================================================================

backup_settings() {
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        local backup_file="$CLAUDE_SETTINGS.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CLAUDE_SETTINGS" "$backup_file"
        log_info "Backup created: $backup_file"
    fi
}

update_claude_settings() {
    local provider="$1"

    # Load environment variables
    load_env_file

    # Backup existing settings
    backup_settings

    # Manage proxy lifecycle (start/stop as needed)
    if ! manage_proxy "$provider"; then
        log_error "Proxy management failed"
        return 1
    fi

    # Create settings directory if needed
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

    # Get provider configuration from JSON
    local provider_env
    provider_env=$(jq -c ".providers.\"$provider\".env" "$PROVIDERS_JSON")

    if [[ "$provider_env" == "null" ]]; then
        log_error "Provider not found in providers.json: $provider"
        return 1
    fi

    # Build env object with expanded variables
    local env_json='{'
    local first=true

    while IFS='=' read -r key value; do
        # Skip empty lines
        [[ -z "$key" ]] && continue

        # Expand variables in value
        value=$(expand_vars "$value")

        # Build JSON
        if [[ "$first" == true ]]; then
            first=false
        else
            env_json+=','
        fi

        # Properly escape value for JSON
        value=$(echo "$value" | jq -R .)
        env_json+="\"$key\":$value"

    done < <(echo "$provider_env" | jq -r 'to_entries[] | "\(.key)=\(.value)"')

    env_json+='}'

    # Create complete settings JSON
    local settings_json
    settings_json=$(cat <<EOF
{
  "env": $env_json
}
EOF
)

    # Write settings
    echo "$settings_json" | jq . > "$CLAUDE_SETTINGS"
    chmod 600 "$CLAUDE_SETTINGS"

    log_success "Claude Code settings updated: $CLAUDE_SETTINGS"
    set_current_provider "$provider"
}

#==============================================================================
# Interactive Menu
#==============================================================================

show_menu() {
    local current_provider
    current_provider=$(get_current_provider)
    local current_name
    current_name=$(get_provider_name "$current_provider")

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  Claude Code Provider Manager v2.0          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Current provider: ${GREEN}$current_name${NC} ($current_provider)"
    echo ""

    # Check if .env exists
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found!"
        log_info "Create it from template:"
        echo "  cp $PROVIDERS_DIR/.env.template $ENV_FILE"
        echo "  nano $ENV_FILE"
        echo ""
        printf "Press Enter to exit..."
        read -r
        exit 1
    fi

    echo "Available providers:"

    local providers
    mapfile -t providers < <(get_available_providers)

    local i=1
    for provider in "${providers[@]}"; do
        local name description
        name=$(get_provider_name "$provider")
        description=$(get_provider_description "$provider")

        if [[ "$provider" == "$current_provider" ]]; then
            echo -e "  ${GREEN}$i)${NC} $name ${GREEN}(active)${NC}"
        else
            echo -e "  $i) $name"
        fi
        echo -e "     ${BLUE}$description${NC}"
        ((i++))
    done

    echo ""
    echo "  s) Show current configuration"
    echo "  e) Edit .env file"
    echo "  b) Backup current settings"
    echo "  r) Restore from backup"
    echo "  q) Quit"
    echo ""

    printf "Select option: "
}

show_current_config() {
    echo ""
    echo -e "${CYAN}Current Configuration:${NC}"
    echo ""

    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        jq . "$CLAUDE_SETTINGS"
    else
        log_warning "No Claude settings file found"
    fi

    echo ""
    printf "Press Enter to continue..."
    read -r
}

edit_env_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warning ".env file not found, creating from template..."
        cp "$PROVIDERS_DIR/.env.template" "$ENV_FILE"
    fi

    local editor="${EDITOR:-nano}"
    "$editor" "$ENV_FILE"
}

restore_from_backup() {
    local backups
    mapfile -t backups < <(find "$(dirname "$CLAUDE_SETTINGS")" -name "settings.json.backup.*" | sort -r)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warning "No backups found"
        sleep 2
        return
    fi

    echo ""
    echo "Available backups:"
    local i=1
    for backup in "${backups[@]}"; do
        local timestamp
        timestamp=$(basename "$backup" | sed 's/settings.json.backup.//')
        echo "  $i) $timestamp"
        ((i++))
    done
    echo ""
    printf "Select backup to restore (or q to cancel): "
    read -r selection

    if [[ "$selection" == "q" ]]; then
        return
    fi

    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#backups[@]} ]]; then
        local backup_file="${backups[$((selection-1))]}"
        cp "$backup_file" "$CLAUDE_SETTINGS"
        log_success "Settings restored from: $(basename "$backup_file")"
        sleep 2
    else
        log_error "Invalid selection"
        sleep 2
    fi
}

#==============================================================================
# Main Loop
#==============================================================================

main() {
    # Check dependencies
    check_dependencies

    # Check if providers directory exists
    if [[ ! -d "$PROVIDERS_DIR" ]]; then
        log_error "Providers directory not found: $PROVIDERS_DIR"
        exit 1
    fi

    # Direct switch mode if parameter provided
    if [[ -n "${1:-}" ]]; then
        direct_switch "$1"
        exit $?
    fi

    # Interactive mode
    while true; do
        clear
        show_menu

        read -r choice

        case "$choice" in
            [1-9]|[1-9][0-9])
                local providers
                mapfile -t providers < <(get_available_providers)
                local idx=$((choice - 1))

                if [[ $idx -ge 0 ]] && [[ $idx -lt ${#providers[@]} ]]; then
                    local selected_provider="${providers[$idx]}"
                    local display_name
                    display_name=$(get_provider_name "$selected_provider")

                    echo ""
                    log_info "Switching to: $display_name"

                    if update_claude_settings "$selected_provider"; then
                        log_success "Provider switched successfully!"
                        log_warning "Please restart Claude Code for changes to take effect"
                        sleep 3
                    else
                        log_error "Failed to switch provider"
                        sleep 3
                    fi
                else
                    log_error "Invalid selection"
                    sleep 2
                fi
                ;;
            s|S)
                show_current_config
                ;;
            e|E)
                edit_env_file
                ;;
            b|B)
                backup_settings
                log_success "Backup created"
                sleep 2
                ;;
            r|R)
                restore_from_backup
                ;;
            q|Q)
                echo ""
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option"
                sleep 2
                ;;
        esac
    done
}

#==============================================================================
# Direct Switch Mode
#==============================================================================

direct_switch() {
    local input="$1"
    local providers
    mapfile -t providers < <(get_available_providers)

    local selected_provider=""
    local display_name=""

    # Check if input is a number
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local idx=$((input - 1))
        if [[ $idx -ge 0 ]] && [[ $idx -lt ${#providers[@]} ]]; then
            selected_provider="${providers[$idx]}"
        else
            log_error "Invalid provider number: $input"
            log_info "Available providers: 1-${#providers[@]}"
            return 1
        fi
    else
        # Search by type (e.g., "minimax", "anthropic", "2-minimax")
        for provider in "${providers[@]}"; do
            if [[ "$provider" == "$input" ]] || [[ "$provider" == *"$input"* ]]; then
                selected_provider="$provider"
                break
            fi
        done

        if [[ -z "$selected_provider" ]]; then
            log_error "Provider not found: $input"
            log_info "Available providers:"
            local i=1
            for provider in "${providers[@]}"; do
                local name
                name=$(get_provider_name "$provider")
                echo "  $i) $provider ($name)"
                ((i++))
            done
            return 1
        fi
    fi

    display_name=$(get_provider_name "$selected_provider")

    log_info "Switching to: $display_name"

    if update_claude_settings "$selected_provider"; then
        log_success "Provider switched successfully to: $display_name"
        log_warning "Please restart Claude Code for changes to take effect"
        return 0
    else
        log_error "Failed to switch provider"
        return 1
    fi
}

# Run main
main "$@"
