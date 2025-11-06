#!/bin/bash
# Claude Code Model Aliases
# Source this file to add convenient aliases: source claude-aliases.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/claude-with-model.sh"

# Create aliases for different models
alias claude-minimax="$LAUNCHER minimax"
alias claude-glm="$LAUNCHER glm"
alias claude-sonnet="$LAUNCHER sonnet"
alias claude-haiku="$LAUNCHER haiku"
alias claude-opus="$LAUNCHER opus"

# Show loaded aliases
echo "🎯 Claude Code Model Aliases loaded:"
echo "  claude-minimax  - MiniMax M2 (fastest, cheapest)"
echo "  claude-glm      - GLM-4.6 via OpenRouter (balanced)"
echo "  claude-sonnet   - Claude Sonnet → GLM-4.6 (quality)"
echo "  claude-haiku    - Claude Haiku → MiniMax (fast)"
echo "  claude-opus     - Claude Opus → GLM-4.6 (quality)"
echo ""
echo "Usage examples:"
echo "  claude-minimax"
echo "  claude-glm -p 'analyze this code'"
echo "  claude-sonnet --dangerously-skip-permissions"
