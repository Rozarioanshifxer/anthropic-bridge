#!/bin/bash
# Code Generation Test for smart-router
# Tests each provider's ability to generate code

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICE_URL="http://localhost:3000"
RESULTS_DIR="tests/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"

# Code generation test
test_code_generation() {
  local model=$1
  local test_name=$2

  echo -e "${BLUE}═══════════════════════════════════════${NC}"
  echo -e "${BLUE}Testing Code Generation: $model${NC}"
  echo -e "${BLUE}═══════════════════════════════════════${NC}"

  local query="Write a Python function to calculate fibonacci numbers. Include docstring and type hints. Keep it concise."
  local result_file="$RESULTS_DIR/${test_name}_code_${TIMESTAMP}.json"

  echo "Query: $query"
  echo ""

  local start_time=$(date +%s)

  curl -s -X POST "$SERVICE_URL/v1/messages" \
    -H "Content-Type: application/json" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
      \"model\": \"$model\",
      \"max_tokens\": 2048,
      \"messages\": [{
        \"role\": \"user\",
        \"content\": \"$query\"
      }]
    }" > "$result_file"

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Extract and display code
  echo -e "${YELLOW}Response:${NC}"
  cat "$result_file" | jq -r '.content[0].text // .error.message // .'
  echo ""

  echo -e "${GREEN}✓ Completed in ${duration}s${NC}"
  echo -e "${GREEN}✓ Result saved to: $result_file${NC}"
  echo ""
}

# Math problem test
test_math_reasoning() {
  local model=$1
  local test_name=$2

  echo -e "${BLUE}═══════════════════════════════════════${NC}"
  echo -e "${BLUE}Testing Math Reasoning: $model${NC}"
  echo -e "${BLUE}═══════════════════════════════════════${NC}"

  local query="A train travels at 60 mph and needs to cover 180 miles. Think step by step: How long will the journey take?"
  local result_file="$RESULTS_DIR/${test_name}_math_${TIMESTAMP}.json"

  echo "Query: $query"
  echo ""

  local start_time=$(date +%s)

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
    }" > "$result_file"

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  echo -e "${YELLOW}Response:${NC}"
  cat "$result_file" | jq -r '.content[0].text // .error.message // .' | head -10
  echo ""

  echo -e "${GREEN}✓ Completed in ${duration}s${NC}"
  echo -e "${GREEN}✓ Result saved to: $result_file${NC}"
  echo ""
}

echo "═════════════════════════════════════════════"
echo "Smart Router Advanced Testing"
echo "═════════════════════════════════════════════"
echo ""

# Test each provider
echo -e "${BLUE}1. GLM 4.6 (Chinese AI)${NC}"
test_code_generation "z-ai/glm-4.6:exacto" "glm"
test_math_reasoning "z-ai/glm-4.6:exacto" "glm"

echo -e "${BLUE}2. Deepseek Chat (Code Specialist)${NC}"
test_code_generation "deepseek/deepseek-chat" "deepseek"
test_math_reasoning "deepseek/deepseek-chat" "deepseek"

echo -e "${BLUE}3. Qwen 2.5 Coder (Code Generation)${NC}"
test_code_generation "qwen/qwen-2.5-coder-32b-instruct" "qwen"
test_math_reasoning "qwen/qwen-2.5-coder-32b-instruct" "qwen"

echo -e "${BLUE}4. GPT-4o (OpenAI)${NC}"
test_code_generation "openai/gpt-4o" "gpt4o"
test_math_reasoning "openai/gpt-4o" "gpt4o"

echo -e "${BLUE}5. Claude Sonnet 4 (Anthropic)${NC}"
test_code_generation "anthropic/claude-sonnet-4" "claude"
test_math_reasoning "anthropic/claude-sonnet-4" "claude"

echo -e "${BLUE}6. Gemini 2.5 Pro (Google)${NC}"
test_code_generation "google/gemini-2.5-pro-preview" "gemini"
test_math_reasoning "google/gemini-2.5-pro-preview" "gemini"

echo "═════════════════════════════════════════════"
echo -e "${GREEN}All advanced tests completed!${NC}"
echo "Results directory: $RESULTS_DIR"
echo "═════════════════════════════════════════════"
