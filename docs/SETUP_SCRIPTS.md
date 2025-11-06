# Setup Scripts Guide

Smart Router v1.0 includes automated setup scripts to simplify initial configuration.

## 📋 Overview

Two setup scripts are provided:
- **setup.sh** - For Linux, macOS, and WSL
- **setup.ps1** - For Windows PowerShell

These scripts interactively guide you through the initial configuration process.

## 🚀 Usage

### Linux/macOS/WSL

```bash
# Make executable (if needed)
chmod +x setup.sh

# Run setup
./setup.sh
```

### Windows PowerShell

```powershell
# Run setup
.\setup.ps1
```

### With Parameters (Advanced)

**PowerShell only:**
```powershell
.\setup.ps1 -ApiKey "sk-or-v1-your-key" -Port 3000 -Environment production
```

## ✨ What the Scripts Do

1. **Check for existing .env file**
   - Prompts before overwriting
   - Safe for repeat runs

2. **Collect configuration:**
   - OpenRouter API key (required)
   - Server port (default: 3000)
   - Environment (default: production)

3. **Validate inputs:**
   - API key format checking
   - Port number validation (1-65535)

4. **Create .env file:**
   - Secure file permissions
   - Stores configuration safely

5. **Test API key:**
   - Validates with OpenRouter API
   - Confirms key is working

6. **Display summary:**
   - Shows configuration
   - Provides next steps

## 📝 Example Output

### setup.sh Output

```
╔════════════════════════════════════════════════════════════╗
║        Smart Router v1.0 - Initial Configuration         ║
╚════════════════════════════════════════════════════════════╝

📝 Configuration Setup

Enter your OpenRouter API Key: ********************
Port for Smart Router (default: 3000):
Environment (default: production):
🎯 Claude Settings Files
The following settings files will be available:
  • config/glm.json.example    (GLM-4.6 model)
  • config/gpt-4o.json.example (GPT-4o model)

📝 Creating .env file...
✅ Created .env file successfully!

🔑 Validating API Key with OpenRouter...
✅ API Key is valid!

📋 Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
API Key:    ********************************
Port:       3000
Environment: production
.env file:  Created
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 Next Steps:

1. Native deployment:
   ./scripts/router-control.sh start

2. Docker deployment:
   docker-compose up -d

3. Test with Claude:
   claude --settings config/glm.json.example -p "Hello"

💡 Health Check:
After starting, verify with: curl http://localhost:3000/health

✅ Setup completed successfully!
```

## 🔒 Security Features

### Input Security
- API key input is masked (not echoed to terminal)
- PowerShell uses SecureString for extra protection
- Validates API key format before saving

### File Security
- Sets secure permissions on .env file (600 on Unix)
- Uses .gitignore to prevent accidental commits
- Environment variables never logged

### Validation
- Tests API key with OpenRouter before completing
- Checks port range (1-65535)
- Confirms before overwriting existing config

## 📦 Generated Files

After running setup scripts, the following files are created:

### `.env`
Contains your configuration:
```bash
# Smart Router Configuration
# Generated on: 2025-11-06 08:15:00

# OpenRouter API Key (REQUIRED)
OPENROUTER_API_KEY=sk-or-v1-your-key-here

# Server Configuration
PORT=3000
NODE_ENV=production
```

## 🐛 Troubleshooting

### Permission Denied (Linux/macOS)

```bash
chmod +x setup.sh
./setup.sh
```

### Execution Policy (Windows PowerShell)

```powershell
# If you get execution policy error:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\setup.ps1
```

### curl not found

The script will skip API validation if curl is not installed. You can manually verify:
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
     https://openrouter.ai/api/v1/models
```

### API Key Validation Failed

1. Verify your API key at https://openrouter.ai/keys
2. Check key hasn't expired
3. Ensure key has proper permissions
4. Try regenerating the key

### Port Already in Use

Change the port during setup:
```
Port for Smart Router (default: 3000): 3001
```

Update docker-compose.yml port mapping if using Docker.

## 📚 Next Steps

After running setup:

1. **Test the configuration:**
   ```bash
   # Start the router
   ./scripts/router-control.sh start

   # Or use Docker
   docker-compose up -d
   ```

2. **Verify health:**
   ```bash
   curl http://localhost:3000/health
   ```

3. **Test with Claude:**
   ```bash
   claude --settings config/glm.json.example -p "Hello"
   ```

## 📄 Files Reference

- **setup.sh** - Linux/macOS/WSL setup script
- **setup.ps1** - Windows PowerShell setup script
- **.env** - Generated configuration file (not tracked in git)
- **.env.example** - Template configuration file

---

**Version**: 1.0
**Last Updated**: 2025-11-06
