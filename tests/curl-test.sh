#!/bin/bash
# Direct HTTP testing of smart-router with curl
# This bypasses claude CLI and tests the service directly

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Service URL
SERVICE_URL="http://localhost:3000"
RESULTS_DIR="tests/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"

# Test function
test_model() {
  local model=$1
  local query=$2
  local test_name=$3

  echo -e "${BLUE}Testing: $model${NC}"
  echo "Query: $query"

  local result_file="$RESULTS_DIR/${test_name}_${TIMESTAMP}.json"

  curl -s -X POST "$SERVICE_URL/v1/messages" \
    -H "Content-Type: application/json" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
      \"model\": \"$model\",
      \"max_tokens\": 1024,
      \"messages\": [{
        \"role\": \"user\",
        \"content\": \"$query\"
      }]
    }" | tee "$result_file" | jq -r '.content[0].text // .error.message // .'

  echo -e "${GREEN}✓ Result saved to: $result_file${NC}"
  echo "---"
}

# Run tests
echo "Smart Router Direct HTTP Testing"
echo "================================="
echo ""

# Test GLM
test_model "z-ai/glm-4.6:exacto" "Rispondi solo con OK se funzioni" "glm_health"

# Test Deepseek
test_model "deepseek/deepseek-chat" "Respond with OK if working" "deepseek_health"

# Test Qwen
test_model "qwen/qwen-2.5-coder-32b-instruct" "简单回复OK" "qwen_health"

# Test GPT-5 (if available)
test_model "openai/gpt-4o" "Just say OK" "gpt4o_health"

# Test Claude
test_model "anthropic/claude-sonnet-4" "Say OK" "claude_health"

# Test Gemini
test_model "google/gemini-2.5-pro-preview" "Reply OK only" "gemini_health"

echo ""
echo "================================="
echo "All tests completed!"
echo "Results in: $RESULTS_DIR"
