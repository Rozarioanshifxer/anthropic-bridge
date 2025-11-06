# Configuration Files

Configuration files for Claude CLI to use different AI models through anthropic-bridge.

## File Format

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:3000",
    "ANTHROPIC_MODEL": "provider/model-name"
  },
  "model": "provider/model-name"
}
```

## Available Models

Available configurations:
- `glm.json` - GLM 4.6 Exacto
- `deepseek-v3.1-terminus.json` - Deepseek Chat
- `qwen3-coder-plus.json` - Qwen 2.5 Coder 32B
- `gpt-5-pro.json` - GPT-4o
- `claude-sonnet-4.5.json` - Claude Sonnet 4
- `gemini-2.5-pro.json` - Gemini 2.5 Pro

## Usage

```bash
# Use with Claude CLI
claude --settings config/glm.json -p "Your query"

# Create new configuration
cp config/gpt-5-pro.json config/custom.json
# Edit model name in custom.json
claude --settings config/custom.json -p "Test query"
```

## Model Names

Format: `provider/model-name`

Find available models at: https://openrouter.ai/models

## Requirements

- Anthropic-bridge service running on `http://localhost:3000` (or your configured URL)
- OpenRouter API key in `.env` file in the project root
