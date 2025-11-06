#!/bin/bash
#
# Anthropic Bridge - Deploy Script (Linux/Mac)
# Supports: Docker, LXC, and Native deployment scenarios
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEPLOYMENT_TYPE=""
CTID=${CTID:-900}
HOST=${HOST:-proxmox}

# Logging
LOG_FILE="/tmp/anthropic-bridge-deploy.log"

log_info() { echo -e "${BLUE}ℹ${NC} $*" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✓${NC} $*" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}✗${NC} $*" | tee -a "$LOG_FILE" >&2; }

# Print banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║       Anthropic Bridge - Deployment Script v1.0          ║"
    echo "║                                                            ║"
    echo "║  Deploy Anthropic → OpenAI Translation Bridge             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if .env exists
    if [ ! -f ".env" ]; then
        log_warning ".env file not found!"
        log_info "Running setup script to create it..."
        if [ -f "./setup.sh" ]; then
            chmod +x ./setup.sh
            ./setup.sh
        else
            log_error "setup.sh not found! Please create .env manually."
            exit 1
        fi
    fi

    # Load environment variables
    set -a
    source .env
    set +a

    # Check API key
    if [ -z "${OPENROUTER_API_KEY:-}" ]; then
        log_error "OPENROUTER_API_KEY not found in .env file!"
        exit 1
    fi

    log_success "Prerequisites check passed"
    echo ""
}

# Deploy Docker
deploy_docker() {
    log_info "Deploying with Docker..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose is not installed!"
        exit 1
    fi

    log_info "Building Docker image..."
    docker build -t anthropic-bridge .

    log_info "Starting containers..."
    docker-compose up -d

    # Wait for service to be ready
    log_info "Waiting for service to be ready..."
    sleep 5

    # Test endpoint
    if curl -s http://localhost:3000/health > /dev/null; then
        log_success "Docker deployment successful!"
        echo ""
        echo -e "${GREEN}✅ Service is running at: http://localhost:3000${NC}"
        echo -e "${GREEN}✅ Health check: http://localhost:3000/health${NC}"
        echo -e "${GREEN}✅ Status: http://localhost:3000/status${NC}"
    else
        log_error "Service health check failed!"
        log_info "View logs: docker-compose logs anthropic-bridge"
        exit 1
    fi
}

# Deploy Native
deploy_native() {
    log_info "Deploying natively..."

    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed!"
        exit 1
    fi

    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed!"
        exit 1
    fi

    # Install dependencies
    log_info "Installing dependencies..."
    npm install

    # Start service
    log_info "Starting service..."
    chmod +x ./scripts/router-control.sh
    ./scripts/router-control.sh start

    # Wait for service
    sleep 3

    # Test
    if curl -s http://localhost:3000/health > /dev/null; then
        log_success "Native deployment successful!"
        echo ""
        echo -e "${GREEN}✅ Service is running at: http://localhost:3000${NC}"
        echo -e "${GREEN}✅ Logs: /tmp/anthropic-bridge.log${NC}"
    else
        log_error "Service health check failed!"
        log_info "View logs: tail -f /tmp/anthropic-bridge.log"
        exit 1
    fi
}

# Deploy LXC
deploy_lxc() {
    log_info "Deploying to LXC container..."

    # Check prerequisites
    if ! command -v ssh &> /dev/null; then
        log_error "SSH is not installed!"
        exit 1
    fi

    if ! command -v pct &> /dev/null; then
        log_error "Proxmox tools (pct) not found! Run this script on Proxmox host."
        exit 1
    fi

    # Run LXC deployment script
    log_info "Running LXC deployment script..."
    chmod +x ./scripts/lxc-deploy.sh
    ./scripts/lxc-deploy.sh "$CTID" "$HOST"

    log_success "LXC deployment completed!"
    echo ""
    echo -e "${GREEN}✅ Container: $CTID${NC}"
    echo -e "${GREEN}✅ Service: anthropic-bridge${NC}"
    echo -e "${GREEN}✅ Access via container IP:3000${NC}"
}

# Main menu
main_menu() {
    print_banner
    echo "Select deployment scenario:"
    echo ""
    echo -e "${CYAN}1)${NC} Docker (Recommended for local testing)"
    echo -e "${CYAN}2)${NC} LXC Container (Proxmox)"
    echo -e "${CYAN}3)${NC} Native (Direct on host)"
    echo -e "${CYAN}4)${NC} Exit"
    echo ""
    read -p "Enter your choice [1-4]: " choice

    case $choice in
        1) DEPLOYMENT_TYPE="docker" ;;
        2) DEPLOYMENT_TYPE="lxc" ;;
        3) DEPLOYMENT_TYPE="native" ;;
        4) log_info "Deployment cancelled."; exit 0 ;;
        *)
            log_error "Invalid choice! Please select 1-4"
            sleep 2
            main_menu
            return
            ;;
    esac
}

# Error handling menu
error_menu() {
    echo ""
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo ""
    echo "What would you like to do?"
    echo -e "${CYAN}1)${NC} Retry"
    echo -e "${CYAN}2)${NC} Back to menu"
    echo -e "${CYAN}3)${NC} Exit"
    echo ""
    read -p "Enter your choice [1-3]: " choice

    case $choice in
        1) return 0 ;;  # Retry
        2) return 1 ;;  # Back to menu
        3) log_info "Deployment cancelled."; exit 0 ;;
        *)
            log_error "Invalid choice!"
            sleep 1
            error_menu
            return $?
            ;;
    esac
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."

    local retries=3
    local count=0

    while [ $count -lt $retries ]; do
        if curl -s http://localhost:3000/health > /dev/null 2>&1; then
            log_success "Deployment verified successfully!"
            return 0
        fi
        count=$((count + 1))
        log_warning "Attempt $count/$retries failed. Retrying..."
        sleep 2
    done

    log_error "Deployment verification failed after $retries attempts"
    return 1
}

# Cleanup on error
cleanup() {
    if [ $? -ne 0 ]; then
        echo ""
        log_error "Deployment failed! Check logs at: $LOG_FILE"
        echo ""
        echo "For Docker, cleanup with:"
        echo "  docker-compose down"
        echo ""
        echo "For Native, stop with:"
        echo "  ./scripts/router-control.sh stop"
    fi
}

trap cleanup EXIT

# Main execution
main() {
    # Start logging
    echo "Deployment started at: $(date)" > "$LOG_FILE"

    while true; do
        main_menu
        check_prerequisites

        log_info "Selected deployment type: $DEPLOYMENT_TYPE"
        echo ""

        # Execute deployment with error handling
        case $DEPLOYMENT_TYPE in
            docker)
                if deploy_docker && verify_deployment; then
                    show_completion
                    break
                else
                    if error_menu; then
                        log_info "Retrying deployment..."
                        continue
                    else
                        log_info "Returning to main menu..."
                        continue
                    fi
                fi
                ;;
            lxc)
                deploy_lxc
                show_completion
                break
                ;;
            native)
                if deploy_native && verify_deployment; then
                    show_completion
                    break
                else
                    if error_menu; then
                        log_info "Retrying deployment..."
                        continue
                    else
                        log_info "Returning to main menu..."
                        continue
                    fi
                fi
                ;;
            *)
                log_error "Invalid deployment type!"
                sleep 2
                continue
                ;;
        esac
    done
}

# Show completion
show_completion() {
    echo ""
    log_success "=========================================="
    log_success "🎉 Deployment completed successfully!"
    log_success "=========================================="
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Test the API: curl http://localhost:3000/health"
    echo "2. View status: curl http://localhost:3000/status"
    echo "3. Test with Claude using settings files in config/"
    echo ""
    echo -e "${CYAN}Management:${NC}"

    case $DEPLOYMENT_TYPE in
        docker)
            echo "  Start:   docker-compose up -d"
            echo "  Stop:    docker-compose down"
            echo "  Logs:    docker-compose logs -f anthropic-bridge"
            echo "  Status:  docker-compose ps"
            ;;
        lxc)
            echo "  Enter:   pct enter $CTID"
            echo "  Status:  pct status $CTID"
            echo "  Logs:    pct enter $CTID -- journalctl -u anthropic-bridge -f"
            ;;
        native)
            echo "  Start:   ./scripts/router-control.sh start"
            echo "  Stop:    ./scripts/router-control.sh stop"
            echo "  Status:  ./scripts/router-control.sh status"
            echo "  Logs:    tail -f /tmp/anthropic-bridge.log"
            ;;
    esac

    echo ""
    echo -e "${GREEN}Log file: $LOG_FILE${NC}"
    echo ""
}

# Check if running with arguments
if [ $# -gt 0 ]; then
    DEPLOYMENT_TYPE=$1
    check_prerequisites

    case $DEPLOYMENT_TYPE in
        docker|docker-compose)
            deploy_docker
            verify_deployment
            ;;
        lxc)
            deploy_lxc
            ;;
        native|local)
            deploy_native
            verify_deployment
            ;;
        *)
            echo "Usage: $0 [docker|lxc|native]"
            exit 1
            ;;
    esac
else
    main
fi
