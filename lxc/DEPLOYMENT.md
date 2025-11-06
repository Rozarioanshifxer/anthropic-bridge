# LXC Deployment Guide for Anthropic Bridge

## Quick Deployment

### 1. Create LXC Container

Using Proxmox web interface or CLI:

```bash
# Create container
pct create 900 local:vztmpl/ubuntu-22.04-standard_22.07-1_amd64.tar.zst \
  --net0 name=eth0,bridge=vmbr0,ip=YOUR_CONTAINER_IP/24,gw=YOUR_GATEWAY \
  --rootfs local-lvm:2 \
  --unprivileged 1 \
  --features nesting=1 \
  --memory 512 \
  --cores 1

# Start container
pct start 900

# Run setup script
pct set 900 -script /var/lib/vz/snippets/anthropic-bridge-setup.sh
pct reboot 900
```

### 2. Deploy Application

On your host, copy files to container:

```bash
# Copy application files
pct push 900 /path/to/anthropic-bridge/src /opt/anthropic-bridge/src
pct push 900 /path/to/anthropic-bridge/scripts /opt/anthropic-bridge/scripts
pct push 900 /path/to/anthropic-bridge/config /opt/anthropic-bridge/config

# Set permissions
pct set 900 -permissions 900:anthropicbridge:anthropicbridge:/opt/anthropic-bridge
```

### 3. Configure Environment

```bash
# Enter container
pct enter 900

# Create environment file
cat > /etc/anthropic-bridge/.env << 'EOF'
OPENROUTER_API_KEY=your_api_key_here
EOF

chown anthropicbridge:anthropicbridge /etc/anthropic-bridge/.env
chmod 600 /etc/anthropic-bridge/.env
```

### 4. Install Systemd Service

```bash
# Copy service file
cp /opt/anthropic-bridge/lxc/anthropic-bridge.service /etc/systemd/system/
chmod 644 /etc/systemd/system/anthropic-bridge.service

# Enable and start
systemctl enable anthropic-bridge
systemctl start anthropic-bridge
```

### 5. Verify

```bash
# Check service status
systemctl status anthropic-bridge

# Test health endpoint
curl http://localhost:3000/health

# View logs
journalctl -u anthropic-bridge -f
```

## Automated Deployment Script

Create `/var/lib/vz/snippets/anthropic-bridge-deploy.sh` on your Proxmox host:

```bash
#!/bin/bash
CTID=900
APP_DIR=/opt/anthropic-bridge

# Start container
pct start $CTID

# Run setup
pct push $CTID /var/lib/vz/snippets/anthropic-bridge-setup.sh /tmp/setup.sh
pct set $CTID -script /tmp/setup.sh
pct reboot $CTID

# Wait for container to be ready
sleep 30

# Copy application
pct push $CTID /path/to/anthropic-bridge $APP_DIR
pct push $CTID /path/to/anthropic-bridge/.env /etc/anthropic-bridge/.env

# Set permissions
pct set $CTID -permissions $CTID:anthropicbridge:anthropicbridge:$APP_DIR

# Reboot to apply
pct reboot $CTID

echo "Anthropic Bridge deployed to LXC container $CTID"
```

## Resource Requirements

- **CPU**: 1 core (minimum)
- **RAM**: 512 MB (minimum)
- **Disk**: 2 GB (minimum)
- **Network**: Bridge connection with internet access

## Management Commands

```bash
# Start container
pct start 900

# Stop container
pct stop 900

# Restart container
pct reboot 900

# Enter container
pct enter 900

# View logs
journalctl -u anthropic-bridge -f

# Check status
curl http://YOUR_CONTAINER_IP:3000/health
```

## Backup

To backup the container:

```bash
# Create backup
vzdump 900 --dumpdir /backup --compress=gzip

# Restore
qmrestore /backup/vzdump-lxc-900-2025_11_06-12_00_00.tar.gz 900
```

## Troubleshooting

### Container won't start

```bash
# Check logs
journalctl -t PCT
pct status 900
```

### Service won't start

```bash
# Check service status
pct enter 900
systemctl status anthropic-bridge
journalctl -u anthropic-bridge
```

### Network issues

```bash
# Check network
pct enter 900
ip addr show
ping 8.8.8.8
```
