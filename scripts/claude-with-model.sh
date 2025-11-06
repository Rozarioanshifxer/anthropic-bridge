#!/bin/bash
# Launch Claude Code with specific model settings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_DIR="$HOME/.claude/settings"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
  echo -e "${BLUE}Claude Code Model Launcher${NC}"
  echo ""
  echo "Usage: $0 <model> [claude-args...]"
  echo ""
  echo "Available models:"
  echo "  ${GREEN}minimax${NC}  - MiniMax M2 (fastest, cheapest)"
  echo "  ${GREEN}glm${NC}      - GLM-4.6 via OpenRouter (balanced)"
  echo "  ${GREEN}sonnet${NC}   - Claude Sonnet → GLM-4.6 (quality)"
  echo "  ${GREEN}haiku${NC}    - Claude Haiku → MiniMax (fast)"
  echo "  ${GREEN}opus${NC}     - Claude Opus → GLM-4.6 (quality)"
  echo ""
  echo "Examples:"
  echo "  $0 minimax"
  echo "  $0 glm -p \"analyze this code\""
  echo "  $0 sonnet --dangerously-skip-permissions"
  echo ""
  echo "Settings files: ~/.claude/settings/*.json"
}

# Check if settings directory exists
if [ ! -d "$SETTINGS_DIR" ]; then
  echo -e "${RED}Error: Settings directory not found: $SETTINGS_DIR${NC}"
  exit 1
fi

# Get model from first argument
MODEL="$1"

if [ -z "$MODEL" ] || [ "$MODEL" = "-h" ] || [ "$MODEL" = "--help" ]; then
  show_help
  exit 0
fi

# Remove model from arguments
shift

# Check if settings file exists
SETTINGS_FILE="$SETTINGS_DIR/$MODEL.json"
if [ ! -f "$SETTINGS_FILE" ]; then
  echo -e "${RED}Error: Settings file not found: $SETTINGS_FILE${NC}"
  echo ""
  echo "Available models:"
  ls -1 "$SETTINGS_DIR"/*.json 2>/dev/null | xargs -n1 basename | sed 's/\.json$//' | sed 's/^/  - /'
  exit 1
fi

# Display model info
echo -e "${BLUE}🚀 Launching Claude Code with ${GREEN}$MODEL${BLUE} model${NC}"
echo -e "${BLUE}📁 Settings: ${NC}$SETTINGS_FILE"
echo ""

# Check if smart router is running
if ! curl -s http://localhost:3000/health > /dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  Smart Router not running, starting it...${NC}"
  "$SCRIPT_DIR/router-control.sh" start
  sleep 2
fi

# Launch Claude Code with specified settings
exec claude --settings "$SETTINGS_FILE" "$@"
