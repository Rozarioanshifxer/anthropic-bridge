# Anthropic Bridge - OpenRouter Proxy Service

**Translation Service**: Anthropic API format → OpenAI format → OpenRouter

Convert Anthropic's message format to OpenAI's chat completions format and route to OpenRouter for multi-model access.

## 🚀 Deployment Options

### ✅ LXC Container (Proxmox) - RECOMMENDED FOR PRODUCTION

**Status**: ✅ ACTIVE - All 6 models verified working
**Documentation**: `docs/LXC_DEPLOYMENT.md`

**Quick Access**:
```bash
# Health check
curl http://localhost:3000/health

# Test with Claude CLI
export ANTHROPIC_BASE_URL="http://localhost:3000"
claude --settings config/glm.json -p "Your query"
```

**Service Management** (on Proxmox host):
```bash
# Restart service
pct exec <container-id> -- systemctl restart anthropic-bridge

# View logs
pct exec <container-id> -- journalctl -u anthropic-bridge -f
```

### 🐳 Docker - WORKS WITH LIMITATIONS

**Status**: ✅ Container works internally, ⚠️ Network access from host may have IPv6 issues on WSL2
**Documentation**: `docs/DOCKER_LXC_DEPLOYMENT.md`

**Deploy**:
```bash
docker-compose up -d
```

**Test from inside container**:
```bash
docker exec anthropic-bridge curl http://localhost:3000/health
```

### 💻 Native - DEVELOPMENT

**Status**: ✅ All 6 models verified working

**Start**:
```bash
./scripts/start-anthropic-bridge.sh
```

Or manually:
```bash
cd smart-router
export OPENROUTER_API_KEY="your-key-here"
node src/anthropic-bridge.js
```

## 🎯 Supported Models (6 Total)

All models verified working:

1. **GLM 4.6 Exacto** - `z-ai/glm-4.6:exacto`
2. **Deepseek Chat** - `deepseek/deepseek-chat`
3. **Qwen 2.5 Coder 32B** - `qwen/qwen-2.5-coder-32b-instruct`
4. **GPT-4o** - `openai/gpt-4o`
5. **Claude Sonnet 4** - `anthropic/claude-sonnet-4`
6. **Gemini 2.5 Pro** - `google/gemini-2.5-pro-preview`

## 📁 Project Structure

```
smart-router/
├── src/
│   └── anthropic-bridge.js         # Main service (Anthropic to OpenAI translator)
├── config/                          # Claude CLI configuration files
│   ├── glm.json                    # GLM 4.6 Exacto
│   ├── deepseek-v3.1-terminus.json # Deepseek Chat
│   ├── qwen3-coder-plus.json       # Qwen 2.5 Coder 32B
│   ├── gpt-5-pro.json              # GPT-4o
│   ├── claude-sonnet-4.5.json      # Claude Sonnet 4
│   └── gemini-2.5-pro.json         # Gemini 2.5 Pro
├── scripts/
│   └── start-anthropic-bridge.sh   # Native startup script
├── docs/
│   ├── LXC_DEPLOYMENT.md           # LXC production deployment (RECOMMENDED)
│   ├── DOCKER_LXC_DEPLOYMENT.md    # Docker deployment guide
│   └── CLI_TESTING.md              # Claude CLI testing guide
├── .env                             # OpenRouter API key
├── package.json
└── README.md
```

## 🔧 Configuration

### Environment Variables

**Required**:
- `OPENROUTER_API_KEY` - Your OpenRouter API key from https://openrouter.ai/

**Optional**:
- `PORT` - Server port (default: 3000)
- `NODE_ENV` - Environment (development/production)

### Claude CLI Configuration

Each model has a configuration file in `config/` directory:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:3000",
    "ANTHROPIC_MODEL": "z-ai/glm-4.6:exacto"
  },
  "model": "z-ai/glm-4.6:exacto"
}
```

**Usage**:
```bash
# Use GLM 4.6
claude --settings config/glm.json -p "Your query"

# Use Deepseek
claude --settings config/deepseek-v3.1-terminus.json -p "Your query"

# Use Claude Sonnet 4
claude --settings config/claude-sonnet-4.5.json -p "Your query"
```

## 📊 Service Architecture

```
┌─────────────┐     Anthropic      ┌──────────────────┐     OpenAI       ┌────────────┐
│ Claude CLI  │────────────────────▶│ anthropic-bridge │──────────────────▶│ OpenRouter │
│             │   Format Request   │ (Translation)     │   Format Request │            │
└─────────────┘                     └──────────────────┘                   └────────────┘
                                            │
                                            ▼
                                    ┌──────────────┐
                                    │ Model Router │
                                    └──────────────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    ▼                       ▼                       ▼
                ┌─────┐               ┌──────────┐            ┌──────────┐
                │ GLM │               │ Deepseek │            │ Claude   │
                │GPT-4│               │ Qwen     │            │ Gemini   │
                └─────┘               └──────────┘            └──────────┘
```

## 📈 Monitoring

### Service Logs (LXC)
```bash
# Real-time logs
pct exec <container-id> -- journalctl -u anthropic-bridge -f

# Last 50 lines
pct exec <container-id> -- journalctl -u anthropic-bridge -n 50

# Follow routing activity
pct exec <container-id> -- journalctl -u anthropic-bridge -f | grep -E 'Forwarding|Response'
```

### Health Check
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "Smart Router",
  "provider": "OpenRouter",
  "mode": "anthropic-to-openai-translator"
}
```

## 🔐 Security

- API key stored in `.env` file (not committed to git)
- Service runs in isolated container
- Unprivileged container (non-root user namespace)
- Internal network only (no external exposure by default)

## 📝 License

MIT

## 👤 Author

Marco Del Pin - marco.delpin@gmail.com

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

**Status**: ✅ PRODUCTION READY - All 6 models operational
**Last Updated**: 2025-11-06
