# CLI Testing Guide for Smart Router

## Overview

This project uses **Claude CLI** for testing instead of traditional TypeScript/Jest tests. This approach allows for real-world testing of the smart-router service with actual AI models.

## Prerequisites

1. **Smart Router running**: Ensure the service is running on port 3000
2. **Claude CLI installed**: Have Claude CLI available in your system
3. **Model configurations**: Prepare JSON configuration files in `config/` directory

## Testing Command Format

```bash
claude --settings <config-file.json> -p "<test query>"
```

### Command Components

- `--settings`: Path to model configuration JSON file
- `-p`: Prompt/query to test with the model
- `<config-file.json>`: Configuration file that points to the smart-router endpoint

## Configuration Files

Configuration files should be created from the examples in `config/` directory:

```bash
# Copy example configuration
cp config/glm-4.6-exacto.json.example config/glm-4.6-exacto.json

# Edit with your settings
nano config/glm-4.6-exacto.json
```

### Example Configuration Structure

```json
{
  "apiKey": "sk-or-v1-your-openrouter-key",
  "baseURL": "http://localhost:3000",
  "model": "zhipu/glm-4-plus"
}
```

## Test Scenarios

### 1. Health Check Test

**Purpose**: Verify the service is responding

```bash
claude --settings config/glm-4.6-exacto.json -p "Hello, are you working?"
```

**Expected**: Response from the configured AI model through smart-router

### 2. Simple Query Test

**Purpose**: Test basic functionality

```bash
claude --settings config/glm-4.6-exacto.json -p "What is 2+2?"
```

**Expected**: Correct mathematical answer

### 3. Code Generation Test

**Purpose**: Test complex reasoning and code generation

```bash
claude --settings config/glm-4.6-exacto.json -p "Write a Python function to calculate fibonacci numbers"
```

**Expected**: Valid Python code with proper function definition

### 4. Multi-turn Conversation Test

**Purpose**: Test conversation context handling

```bash
# First query
claude --settings config/glm-4.6-exacto.json -p "My name is Marco"

# Follow-up query (if CLI supports conversation context)
claude --settings config/glm-4.6-exacto.json -p "What is my name?"
```

**Expected**: Model should remember the name from previous interaction

### 5. Model-specific Features Test

**Purpose**: Test features specific to each model

```bash
# For GLM models - test Chinese language support
claude --settings config/glm-4.6-exacto.json -p "你好，请介绍一下你自己"

# For Deepseek - test code analysis
claude --settings config/deepseek-v3.1-terminus.json -p "Analyze this code: def foo(): pass"

# For GPT models - test general knowledge
claude --settings config/gpt-5-pro.json -p "Explain quantum computing in simple terms"
```

### 6. Error Handling Test

**Purpose**: Test service error handling

```bash
# Test with invalid model
claude --settings config/invalid-model.json -p "Test error handling"

# Test with malformed request (if possible through CLI)
```

**Expected**: Graceful error messages

## Available Model Configurations

Based on config directory examples:

- **Claude Sonnet 4.5**: `claude-sonnet-4.5.json`
- **Deepseek V3.1**: `deepseek-v3.1-terminus.json`, `deepseek-v3.1-terminus-exacto.json`
- **Gemini 2.5 Pro**: `gemini-2.5-pro.json`
- **GLM 4.6**: `glm-4.6-exacto.json`
- **GPT-5**: `gpt-5-codex.json`, `gpt-5-pro.json`
- **Kimi K2**: `kimi-k2-0905-exacto.json`
- **Qwen3 Coder**: `qwen3-coder-flash.json`, `qwen3-coder-plus.json`

## Test Execution Workflow

1. **Start smart-router service**
   ```bash
   npm start
   # or with Docker
   npm run docker:compose:up
   ```

2. **Prepare configuration files**
   ```bash
   cd config/
   # Copy and edit configuration for your target model
   cp glm-4.6-exacto.json.example glm.json
   nano glm.json  # Add your OpenRouter API key
   ```

3. **Run test queries**
   ```bash
   # Basic health check
   claude --settings config/glm.json -p "Hello"

   # More complex test
   claude --settings config/glm.json -p "Explain how smart-router works"
   ```

4. **Check service logs**
   ```bash
   # If running with Docker
   npm run docker:compose:logs

   # If running directly
   # Check console output from npm start
   ```

5. **Verify results**
   - Check that responses are formatted correctly
   - Verify model-specific features work
   - Ensure error handling is graceful

## Troubleshooting

### Service Not Responding

```bash
# Check if service is running
curl http://localhost:3000/v1/health

# Check logs
npm run docker:compose:logs
```

### Invalid Configuration

```bash
# Verify JSON syntax
cat config/glm.json | jq .

# Test with minimal config
echo '{"apiKey":"sk-or-v1-xxx","baseURL":"http://localhost:3000","model":"test"}' | jq .
```

### API Key Issues

Ensure your OpenRouter API key is valid:
- Check `.env` file has `OPENROUTER_API_KEY` set
- Verify the key format: `sk-or-v1-...`
- Test directly with OpenRouter API first

## Continuous Testing

For continuous development, consider:

1. **Create test script**
   ```bash
   #!/bin/bash
   # tests/run-cli-tests.sh

   for config in config/*.json; do
     echo "Testing with $config"
     claude --settings "$config" -p "Test query: What is 2+2?"
   done
   ```

2. **Run tests regularly**
   ```bash
   chmod +x tests/run-cli-tests.sh
   ./tests/run-cli-tests.sh
   ```

3. **Monitor for regressions**
   - Keep test queries consistent
   - Document expected responses
   - Track response times and quality

## Best Practices

1. **Start simple**: Begin with basic queries before complex tests
2. **Document results**: Keep notes on model-specific behaviors
3. **Test incrementally**: Test one feature at a time
4. **Use version control**: Track configuration changes in git
5. **Monitor logs**: Always check service logs for errors
6. **Compare models**: Test same query across different models to compare behavior

## Next Steps

After basic testing:

1. Create model-specific test suites
2. Document model capabilities and limitations
3. Build automated test scripts
4. Set up performance benchmarks
5. Create regression test suite
