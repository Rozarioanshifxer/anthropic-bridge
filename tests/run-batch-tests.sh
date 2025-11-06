#!/bin/bash
# Smart Router CLI Batch Testing Script
# Usage: ./tests/run-batch-tests.sh [config-name]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Log file with timestamp
LOG_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/batch_test_$TIMESTAMP.log"

# Results directory
RESULTS_DIR="$PROJECT_ROOT/tests/results"
mkdir -p "$LOG_DIR" "$RESULTS_DIR"

# Configuration
DEFAULT_CONFIGS=(
  "config/glm.json"
  "config/deepseek-v3.1-terminus.json"
  "config/qwen3-coder-plus.json"
)

# Test queries
TEST_QUERIES=(
  "Hello, respond with 'OK' if you are working"
  "Calculate: 2+2"
  "Write a Python function to reverse a string"
)

# Function to log with timestamp
log() {
  local level=$1
  shift
  local message="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Function to check if service is running
check_service() {
  log "INFO" "Checking if smart-router is running..."
  if curl -s http://localhost:3000/v1/health > /dev/null 2>&1; then
    log "INFO" "${GREEN}Smart-router service is running${NC}"
    return 0
  else
    log "ERROR" "${RED}Smart-router service is NOT running${NC}"
    log "ERROR" "Please start the service with: npm start or docker-compose up"
    return 1
  fi
}

# Function to validate config file
validate_config() {
  local config=$1
  if [[ ! -f "$config" ]]; then
    log "ERROR" "${RED}Config file not found: $config${NC}"
    return 1
  fi

  # Check if it's valid JSON
  if ! jq . "$config" > /dev/null 2>&1; then
    log "ERROR" "${RED}Invalid JSON in config: $config${NC}"
    return 1
  fi

  log "INFO" "${GREEN}Config valid: $config${NC}"
  return 0
}

# Function to run a single test
run_test() {
  local config=$1
  local query=$2
  local test_num=$3

  local config_name=$(basename "$config" .json)
  local result_file="$RESULTS_DIR/${config_name}_test${test_num}_$TIMESTAMP.txt"

  log "INFO" "${BLUE}Running test $test_num with $config_name${NC}"
  log "INFO" "Query: ${YELLOW}$query${NC}"

  # Run the test and capture timing
  local start_time=$(date +%s.%N)

  if claude --settings "$config" -p "$query" > "$result_file" 2>&1; then
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    log "INFO" "${GREEN}✓ Test $test_num completed in ${duration}s${NC}"
    log "INFO" "Result saved to: $result_file"

    # Show first few lines of response
    echo -e "${BLUE}Response preview:${NC}"
    head -n 3 "$result_file"
    echo "..."

    return 0
  else
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    log "ERROR" "${RED}✗ Test $test_num failed after ${duration}s${NC}"
    log "ERROR" "Error output saved to: $result_file"

    return 1
  fi
}

# Function to run all tests for a config
run_config_tests() {
  local config=$1
  local config_name=$(basename "$config" .json)
  local passed=0
  local failed=0

  log "INFO" "${BLUE}========================================${NC}"
  log "INFO" "${BLUE}Testing configuration: $config_name${NC}"
  log "INFO" "${BLUE}========================================${NC}"

  if ! validate_config "$config"; then
    log "ERROR" "Skipping tests for $config_name due to validation error"
    return 1
  fi

  for i in "${!TEST_QUERIES[@]}"; do
    local test_num=$((i + 1))
    local query="${TEST_QUERIES[$i]}"

    if run_test "$config" "$query" "$test_num"; then
      ((passed++))
    else
      ((failed++))
    fi

    # Small delay between tests
    sleep 1
  done

  log "INFO" "${BLUE}========================================${NC}"
  log "INFO" "Results for $config_name:"
  log "INFO" "${GREEN}Passed: $passed${NC} ${RED}Failed: $failed${NC}"
  log "INFO" "${BLUE}========================================${NC}"
  echo ""

  return 0
}

# Main function
main() {
  log "INFO" "${BLUE}Smart Router CLI Batch Testing${NC}"
  log "INFO" "Log file: $LOG_FILE"
  log "INFO" "Results directory: $RESULTS_DIR"
  echo ""

  # Check if service is running
  if ! check_service; then
    exit 1
  fi

  echo ""

  # Determine which configs to test
  local configs_to_test=()

  if [[ $# -gt 0 ]]; then
    # Specific config provided as argument
    local config_arg=$1
    if [[ ! "$config_arg" =~ \.json$ ]]; then
      config_arg="config/${config_arg}.json"
    fi
    configs_to_test=("$config_arg")
  else
    # Test all existing default configs
    for config in "${DEFAULT_CONFIGS[@]}"; do
      if [[ -f "$PROJECT_ROOT/$config" ]]; then
        configs_to_test+=("$PROJECT_ROOT/$config")
      else
        log "WARN" "${YELLOW}Config not found, skipping: $config${NC}"
      fi
    done
  fi

  if [[ ${#configs_to_test[@]} -eq 0 ]]; then
    log "ERROR" "${RED}No valid configurations to test${NC}"
    log "ERROR" "Please create config files from examples:"
    log "ERROR" "  cp config/glm.json.example config/glm.json"
    exit 1
  fi

  # Run tests for each configuration
  local total_configs=${#configs_to_test[@]}
  local configs_passed=0
  local configs_failed=0

  for config in "${configs_to_test[@]}"; do
    if run_config_tests "$config"; then
      ((configs_passed++))
    else
      ((configs_failed++))
    fi
  done

  # Final summary
  log "INFO" "${BLUE}========================================${NC}"
  log "INFO" "${BLUE}FINAL SUMMARY${NC}"
  log "INFO" "${BLUE}========================================${NC}"
  log "INFO" "Total configurations tested: $total_configs"
  log "INFO" "${GREEN}Successful configurations: $configs_passed${NC}"
  log "INFO" "${RED}Failed configurations: $configs_failed${NC}"
  log "INFO" "Full log: $LOG_FILE"
  log "INFO" "Results directory: $RESULTS_DIR"
  log "INFO" "${BLUE}========================================${NC}"

  # Exit with appropriate code
  if [[ $configs_failed -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

# Run main function with all arguments
main "$@"
