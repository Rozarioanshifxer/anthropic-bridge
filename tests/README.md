# Smart Router Testing

This directory contains CLI-based testing resources for the smart-router project.

## Quick Start

1. **Start the smart-router service**:
   ```bash
   cd smart-router
   npm start
   ```

2. **Run a simple test**:
   ```bash
   claude --settings config/glm.json -p "Hello, are you working?"
   ```

3. **Run batch tests**:
   ```bash
   ./tests/run-batch-tests.sh
   ```

## Available Resources

- **`example-queries.md`**: Comprehensive collection of test queries for various scenarios
- **`run-batch-tests.sh`**: Automated batch testing script for multiple configurations
- **`results/`**: Directory where test results are saved (auto-created)

## Configuration Files

Active configuration files are in `config/` directory:
- `glm.json` - GLM 4.6 Exacto model (ready to use)
- `deepseek-v3.1-terminus.json` - Deepseek Chat model
- `qwen3-coder-plus.json` - Qwen 2.5 Coder 32B model
- `gpt-5-pro.json` - GPT-4o model
- `claude-sonnet-4.5.json` - Claude Sonnet 4 model
- `gemini-2.5-pro.json` - Gemini 2.5 Pro model

## Testing Workflow

### Manual Testing

```bash
# Basic test
claude --settings config/glm.json -p "What is 2+2?"

# Code generation
claude --settings config/glm.json -p "Write a Python fibonacci function"

# Timed test
time claude --settings config/glm.json -p "Quick test"
```

### Automated Batch Testing

```bash
# Test all default configurations
./tests/run-batch-tests.sh

# Test specific configuration
./tests/run-batch-tests.sh glm
./tests/run-batch-tests.sh deepseek-v3.1-terminus

# Results saved to tests/results/ with timestamps
```

### Custom Test Queries

Edit `run-batch-tests.sh` and modify the `TEST_QUERIES` array:

```bash
TEST_QUERIES=(
  "Your custom query 1"
  "Your custom query 2"
  "Your custom query 3"
)
```

## Test Types

Refer to `example-queries.md` for:
- Health checks
- Code generation tests
- Language support tests
- Complex reasoning tests
- Model comparison tests
- Performance tests
- Edge case tests

## Logs and Results

- **Logs**: `logs/batch_test_TIMESTAMP.log`
- **Results**: `tests/results/CONFIG_testN_TIMESTAMP.txt`

## Documentation

For detailed testing documentation, see:
- `docs/CLI_TESTING.md` - Complete CLI testing guide
- `example-queries.md` - Test query examples
- `README.md` - Project overview and setup

## Troubleshooting

### Service not responding
```bash
# Check service status
curl http://localhost:3000/health

# Check if running
ps aux | grep node

# Restart service
npm start
```

### Configuration issues
```bash
# Validate JSON
cat config/glm.json | jq .

# Check API key in .env
cat .env | grep OPENROUTER_API_KEY
```

### Claude CLI not found
```bash
# Install Claude CLI if needed
# Follow instructions from Anthropic
```

## Best Practices

1. Always start service before testing
2. Monitor logs during tests: `tail -f logs/anthropic-bridge_*.log`
3. Compare results across models
4. Document unexpected behaviors
5. Keep configuration files in version control
6. Use meaningful test queries that reflect real usage

## Next Steps

1. Create model-specific test suites
2. Set up continuous testing
3. Build performance benchmarks
4. Document model-specific capabilities
5. Create regression test baselines
