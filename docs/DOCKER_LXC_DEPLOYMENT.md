# Docker & LXC Deployment Guide for Anthropic Bridge

## 🐳 Docker Deployment

### Quick Start with Docker Compose

```bash
# 1. Clone repository
git clone https://github.com/YOUR_USERNAME/anthropic-bridge.git
cd anthropic-bridge

# 2. Configure environment
cp .env.example .env
# Edit .env and add your OPENROUTER_API_KEY

# 3. Build and start
docker-compose up -d

# 4. Verify
curl http://localhost:3000/health
```

### Build Docker Image Manually

```bash
# Build image
docker build -t anthropic-bridge .

# Run container
docker run -d \
  --name anthropic-bridge \
  --restart unless-stopped \
  --env-file ./.env \
  -p 3000:3000 \
  anthropic-bridge
```

### Docker Compose Profiles

**Basic (bridge only):**
```bash
docker-compose up -d
```

**With Nginx Reverse Proxy:**
```bash
docker-compose --profile with-nginx up -d
```

**Development Mode:**
```bash
docker-compose -f docker-compose.dev.yml up
```

### Docker Commands

```bash
# View logs
docker-compose logs -f anthropic-bridge

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up -d --build

# Check status
docker-compose ps

# Exec into container
docker-compose exec anthropic-bridge sh
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENROUTER_API_KEY` | - | **Required** - OpenRouter API key |
| `NODE_ENV` | production | Environment mode |
| `PORT` | 3000 | Service port |

### Volumes

- `./logs:/tmp` - Log files persistence

### Network

- Exposed on port 3000
- Network: `anthropic-bridge-network` (bridge)

---

## 🐧 LXC Deployment (Proxmox)

### Prerequisites

- Proxmox VE 7.0+
- Ubuntu 22.04 template
- Available CTID (example: 900)

### Automated Deployment

```bash
# 1. Copy deployment script to Proxmox
scp lxc/anthropic-bridge-deploy.sh root@proxmox:/var/lib/vz/snippets/

# 2. Make executable
ssh root@proxmox "chmod +x /var/lib/vz/snippets/anthropic-bridge-deploy.sh"

# 3. Run deployment
ssh root@proxmox "/var/lib/vz/snippets/anthropic-bridge-deploy.sh"
```

### Manual Deployment

```bash
# 1. Create container
pct create 900 local:vztmpl/ubuntu-22.04-standard_22.07-1_amd64.tar.zst \
  --net0 name=eth0,bridge=vmbr0,ip=YOUR_CONTAINER_IP/24,gw=YOUR_GATEWAY \
  --rootfs local-lvm:2 \
  --unprivileged 1 \
  --features nesting=1 \
  --memory 512 \
  --cores 1 \
  --hostname anthropic-bridge

# 2. Start container
pct start 900

# 3. Run setup script
pct push 900 lxc/setup.sh /tmp/setup.sh
pct set 900 -script /tmp/setup.sh
pct reboot 900

# Wait for setup to complete
sleep 30

# 4. Copy application files
pct push 900 . /opt/anthropic-bridge
pct push 900 lxc/anthropic-bridge.service /etc/systemd/system/

# 5. Create environment file
pct enter 900
cat > /etc/anthropic-bridge/.env << 'EOF'
OPENROUTER_API_KEY=your_api_key_here
EOF

# 6. Set permissions and start service
chown -R anthropicbridge:anthropicbridge /opt/anthropic-bridge
systemctl enable anthropic-bridge
systemctl start anthropic-bridge

# 7. Verify
curl http://localhost:3000/health
```

### LXC Configuration

Edit `lxc/900.conf` to customize:

```bash
# Resources
CPUS: 1
RAM: 512
DISK: 2

# Network (adjust IP as needed)
NET0: name=eth0,bridge=vmbr0,ip=YOUR_CONTAINER_IP/24,gw=YOUR_GATEWAY

# Storage
ROOTFS: local-lvm:vm-900-disk-0
```

### LXC Management

```bash
# Start/Stop/Restart
pct start 900
pct stop 900
pct reboot 900

# Status
pct status 900

# Enter container
pct enter 900

# View logs
pct enter 900
journalctl -u anthropic-bridge -f

# Backup
vzdump 900 --dumpdir /backup --compress=gzip

# Restore
qmrestore /backup/vzdump-lxc-900-2025_11_06-12_00_00.tar.gz 900
```

### LXC Resource Requirements

- **CPU**: 1 core minimum
- **RAM**: 512 MB minimum
- **Disk**: 2 GB minimum
- **Network**: Bridge connection with internet

---

## 🔧 Configuration

### Docker Environment File

Create `.env`:

```bash
OPENROUTER_API_KEY=sk-or-v1-your-key-here
NODE_ENV=production
PORT=3000
```

### LXC Environment File

Create `/etc/anthropic-bridge/.env` inside container:

```bash
OPENROUTER_API_KEY=sk-or-v1-your-key-here
```

---

## 🔍 Testing

### Docker Test

```bash
# Health check
curl http://localhost:3000/health

# Status
curl http://localhost:3000/status

# Test with Claude
claude --settings config/glm.json.example -p "test: 2+2"
```

### LXC Test

```bash
# Inside container
pct enter 900
curl http://localhost:3000/health

# From host
curl http://YOUR_CONTAINER_IP:3000/health
```

---

## 📊 Monitoring

### Docker

```bash
# Container stats
docker stats anthropic-bridge

# View logs
docker-compose logs -f --tail=100 anthropic-bridge

# Health check
curl http://localhost:3000/health
```

### LXC

```bash
# Service status
pct enter 900
systemctl status anthropic-bridge

# Logs
journalctl -u anthropic-bridge -f

# Resources
pct enter 900
free -h
df -h
```

---

## 🚨 Troubleshooting

### Docker Issues

**Container won't start:**
```bash
docker-compose logs anthropic-bridge
docker-compose ps
```

**Port already in use:**
```bash
# Check if port is in use
lsof -i :3000

# Stop conflicting service or change port in docker-compose.yml
```

**Environment variables not loaded:**
```bash
# Check .env file location
ls -la .env

# Verify in container
docker-compose exec anthropic-bridge env | grep OPENROUTER
```

### LXC Issues

**Container won't start:**
```bash
# Check Proxmox logs
journalctl -t PCT

# Check container status
pct status 900
pct config 900
```

**Service won't start:**
```bash
pct enter 900
systemctl status anthropic-bridge
journalctl -u anthropic-bridge -n 50
```

**Network issues:**
```bash
pct enter 900
ip addr show
ping 8.8.8.8
```

---

## 🔐 Security

### Docker Security

- Runs as non-root user (`anthropicbridge`)
- Minimal base image (node:18-alpine)
- No unnecessary packages
- Read-only root filesystem (can be enabled)
- Resource limits

### LXC Security

- Unprivileged container
- NoNewPrivileges enabled in systemd service
- Private tmp directory
- Protected system directories

---

## 📚 Additional Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Container)
- [Anthropic Bridge Source](../src/anthropic-bridge.js)

---

**Version**: 1.0
**Last Updated**: 2025-11-06
