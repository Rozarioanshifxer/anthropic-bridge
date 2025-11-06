# Anthropic Bridge - LXC Deployment (Proxmox)

**Deployment Date**: 2025-11-06
**Status**: ✅ PRODUCTION READY - ALL TESTS CONFIRMED

## 📋 Container Specifications

**Example Configuration**:
- **LXC ID**: 100 (adjust to your needs)
- **Hostname**: anthropic-bridge
- **IP Address**: Configure based on your network
- **OS**: Ubuntu 24.04 LTS
- **Resources**:
  - CPU: 1 core
  - RAM: 512 MB
  - Swap: 512 MB
  - Disk: 4 GB
- **Node.js**: v20.x or later
- **NPM**: v10.x or later

## 🚀 Deployment Steps

### 1. Container Creation

```bash
# Adjust container ID, IP address, and network settings for your environment
pct create 100 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname anthropic-bridge \
  --memory 512 \
  --swap 512 \
  --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=<your-ip>/24,gw=<your-gateway> \
  --rootfs local-lvm:4 \
  --unprivileged 1 \
  --features nesting=1 \
  --description 'Anthropic Bridge - OpenRouter Proxy Service' \
  --onboot 1
```

### 2. Node.js Installation

```bash
# Replace 100 with your container ID
pct exec 100 -- bash -c 'curl -fsSL https://deb.nodesource.com/setup_20.x | bash -'
pct exec 100 -- bash -c 'apt-get install -y nodejs'
```

### 3. Application Deployment

Deploy these files to `/opt/` inside the container:
- `src/anthropic-bridge.js` (main service)
- `config/` (Claude CLI configurations for 6 models)
- `.env` (OpenRouter API key)
- `package.json`

```bash
# Example: Copy files to container
pct push 100 src/anthropic-bridge.js /opt/src/anthropic-bridge.js
pct push 100 .env /opt/.env
# ... repeat for other files
```

### 4. Systemd Service Configuration

Create service file at `/etc/systemd/system/anthropic-bridge.service`:

```ini
[Unit]
Description=Anthropic Bridge - OpenRouter Proxy Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt
EnvironmentFile=/opt/.env
ExecStart=/usr/bin/node /opt/src/anthropic-bridge.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Enable and start service**:
```bash
pct exec 100 -- systemctl daemon-reload
pct exec 100 -- systemctl enable anthropic-bridge
pct exec 100 -- systemctl start anthropic-bridge
pct exec 100 -- systemctl status anthropic-bridge
```

## ✅ Test Results - All 6 Models WORKING

**Test Method**: Execute from inside LXC container or from network client
**Success Rate**: 6/6 (100%)

### Test Examples

Test all models with curl from inside the container:

```bash
# GLM 4.6 Exacto
curl -s -X POST "http://localhost:3000/v1/messages" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model": "z-ai/glm-4.6:exacto", "max_tokens": 10, "messages": [{"role": "user", "content": "Hello"}]}'

# Deepseek Chat
curl -s -X POST "http://localhost:3000/v1/messages" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model": "deepseek/deepseek-chat", "max_tokens": 10, "messages": [{"role": "user", "content": "Hello"}]}'

# Qwen 2.5 Coder 32B
curl -s -X POST "http://localhost:3000/v1/messages" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model": "qwen/qwen-2.5-coder-32b-instruct", "max_tokens": 10, "messages": [{"role": "user", "content": "Hello"}]}'

# GPT-4o
curl -s -X POST "http://localhost:3000/v1/messages" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model": "openai/gpt-4o", "max_tokens": 10, "messages": [{"role": "user", "content": "Hello"}]}'

# Claude Sonnet 4
curl -s -X POST "http://localhost:3000/v1/messages" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model": "anthropic/claude-sonnet-4", "max_tokens": 10, "messages": [{"role": "user", "content": "Hello"}]}'

# Gemini 2.5 Pro Preview
curl -s -X POST "http://localhost:3000/v1/messages" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model": "google/gemini-2.5-pro-preview", "max_tokens": 10, "messages": [{"role": "user", "content": "Hello"}]}'
```

## 🔍 Service Verification

**Health Check**:
```bash
curl http://localhost:3000/health
# Response: {"status":"healthy","service":"Smart Router","provider":"OpenRouter","mode":"anthropic-to-openai-translator"}
```

**Service Status**:
```bash
pct exec 100 -- systemctl status anthropic-bridge
# Status: active (running)
```

**Logs Monitoring**:
```bash
pct exec 100 -- journalctl -u anthropic-bridge -f
```

## 📊 Expected Log Output

When requests are routed to OpenRouter, you should see logs like:

```
→ Forwarding to OpenRouter: z-ai/glm-4.6:exacto
✓ Response received from OpenRouter

→ Forwarding to OpenRouter: deepseek/deepseek-chat
✓ Response received from OpenRouter

→ Forwarding to OpenRouter: qwen/qwen-2.5-coder-32b-instruct
✓ Response received from OpenRouter
```

## 🎯 Usage with Claude CLI

**Configuration Files** deployed in `/opt/config/`:
- `glm.json` - GLM 4.6 Exacto
- `deepseek-v3.1-terminus.json` - Deepseek Chat
- `qwen3-coder-plus.json` - Qwen 2.5 Coder 32B
- `gpt-5-pro.json` - GPT-4o
- `claude-sonnet-4.5.json` - Claude Sonnet 4
- `gemini-2.5-pro.json` - Gemini 2.5 Pro

**Usage from any network client**:
```bash
# Point to your LXC container IP or hostname
export ANTHROPIC_BASE_URL="http://<your-container-ip>:3000"

# Use with Claude CLI
claude --settings config/glm.json -p "Test query"
```

## 🛠️ Maintenance

**Restart Service**:
```bash
pct exec 100 -- systemctl restart anthropic-bridge
```

**View Logs**:
```bash
# Last 50 lines
pct exec 100 -- journalctl -u anthropic-bridge -n 50

# Follow real-time
pct exec 100 -- journalctl -u anthropic-bridge -f
```

**Stop Service**:
```bash
pct exec 100 -- systemctl stop anthropic-bridge
```

**Update Service**:
```bash
# 1. Stop service
pct exec 100 -- systemctl stop anthropic-bridge

# 2. Update files in /opt/ (via pct push or other method)
pct push 100 src/anthropic-bridge.js /opt/src/anthropic-bridge.js

# 3. Restart service
pct exec 100 -- systemctl start anthropic-bridge
```

## 📋 Deployment Comparison

| Feature | Native | Docker | LXC (Proxmox) |
|---------|--------|--------|---------------|
| **Setup Complexity** | Simple | Medium | Medium |
| **Network Access** | Direct | May have issues on WSL2 | Direct |
| **Resource Usage** | Low | Medium | Low |
| **Isolation** | None | Full | Full |
| **Auto-start** | Manual | docker-compose | systemd |
| **Production Ready** | Dev only | Limited (WSL2) | ✅ Yes |
| **Remote Access** | Local | Local/Limited | ✅ Network-wide |
| **Monitoring** | Manual | docker logs | systemd/journald |

## ✅ Production Status

- **Deployment**: COMPLETED
- **Service Status**: ACTIVE and RUNNING
- **API Key**: Loaded from environment
- **Models Tested**: 6/6 (100% success rate)
- **OpenRouter Integration**: CONFIRMED
- **Auto-start**: ENABLED (systemd)
- **Monitoring**: journalctl available

**Recommended for**: Production use on Proxmox infrastructure

---

**Status**: ✅ PRODUCTION READY
**Last Updated**: 2025-11-06
