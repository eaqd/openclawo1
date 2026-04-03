# OpenClaw Setup Guide — Windows PowerShell

You have **Ollama running** on your Windows PC.
Two paths to get chatting:

- **Quick Start** — Web UI only, no npm needed, 30 seconds
- **Full Setup** — Install openclaw for CLI, skills, Telegram (takes longer but much more powerful)

> If `ollama serve` gives "bind: Only one usage of each socket address"
> — **Ollama is already running.** That's good. Don't run it again.

## Choose the right model for your RAM

| Your RAM | Model to pull | Command |
|----------|---------------|---------|
| **8 GB** | `qwen3.5:0.8b` (recommended) | `ollama pull qwen3.5:0.8b` |
| **8 GB** | `qwen3.5:2b` (better, tight fit) | `ollama pull qwen3.5:2b` |
| **16 GB+** | `qwen3.5:4b` (best balance) | `ollama pull qwen3.5:4b` |
| **32 GB+** | `qwen3.5:9b` (highest quality) | `ollama pull qwen3.5:9b` |

> **Important:** `qwen3.5:4b` needs ~14 GB of RAM at runtime. If you have
> 8 GB, it will fail with "model requires more system memory" errors.
> Use `qwen3.5:0.8b` instead — it's ~2 GB and works great on 8 GB systems.

---

# Quick Start — Chat Now (No npm needed)

The web UI is a standalone HTML file that talks directly to your Ollama.
No Node.js, no npm, no extra installs.

### Step 1: Clone the repo (skip if already done)

```powershell
cd $env:USERPROFILE
git clone https://github.com/eaqd/openclawo1.git
```

### Step 2: Allow Ollama to accept browser requests

Ollama blocks browser requests by default. You need to set this once:

```powershell
[System.Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "User")
```

Now **restart Ollama**: right-click the Ollama icon in your system tray
(bottom-right of taskbar) and click **Quit**. Then open Ollama again from
your Start Menu. Wait a few seconds for it to start.

Verify it's running:

```powershell
Invoke-RestMethod http://localhost:11434/api/tags
```

### Step 3: Serve the web UI

```powershell
cd $env:USERPROFILE\openclawo1\web
python -m http.server 8080
```

Leave this PowerShell window open.

### Step 4: Open your browser

Go to:

```
http://localhost:8080
```

You should see the OpenClaw dark-themed chat interface.

### Step 5: Set your model

1. Click the **gear icon** (top-right corner)
2. **Ollama API URL:** `http://localhost:11434` (should already be set)
3. **Model:** Change from `miniclaw` to `qwen3.5:0.8b` (or `qwen3.5:4b` if you have 16GB+ RAM)
4. Click **"Save & Connect"**

The dot should turn **green** ("Connected").

### Step 6: Chat!

Type a message and press Enter. Responses come from your local Qwen 3.5:4b.
No internet needed, no API keys, everything runs on your PC.

**To stop:** Press Ctrl+C in the PowerShell window running the server.

**To start again next time:**
```powershell
cd $env:USERPROFILE\openclawo1\web
python -m http.server 8080
# Then open http://localhost:8080
```

---

# Full Setup — OpenClaw with CLI, Skills, and Telegram

This installs the full OpenClaw package. Takes longer but gives you:
- 52 built-in skills (code generation, data analysis, web search, etc.)
- Terminal UI and CLI chat
- Telegram bot integration
- Model management and diagnostics

You can do this now or later. The Quick Start above works independently.

### Step 1: Install Node.js (if you don't have it)

```powershell
node --version
```

Need v20+. If missing:

```powershell
winget install OpenJS.NodeJS.LTS
```

Close and reopen PowerShell after installing.

### Step 2: Install OpenClaw

```powershell
npm install -g openclaw
```

This takes a while (large package with many dependencies). The `warn deprecated`
messages are normal — they're just warnings, not errors. Let it finish.

Verify when done:

```powershell
openclaw --version
```

### Step 3: Set the environment variable

```powershell
# For this session
$env:OLLAMA_API_KEY = "ollama-local"

# Permanent (persists after restart)
[System.Environment]::SetEnvironmentVariable("OLLAMA_API_KEY", "ollama-local", "User")
```

### Step 4: Copy config files

```powershell
cd $env:USERPROFILE\openclawo1

# Create config directories
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw\workspace"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw\skills"

# Copy config (sets qwen3.5:0.8b as default — safe for 8GB systems)
Copy-Item config\openclaw.json5 "$env:USERPROFILE\.openclaw\openclaw.json"

# Copy env file
Copy-Item .env.example .env

# Validate config (fix any issues)
openclaw doctor --fix
```

> If you see "Unrecognized key" errors, run `openclaw doctor --fix` to
> auto-repair the config. Then set your model manually:
> ```powershell
> openclaw config set agents.defaults.model.primary "ollama/qwen3.5:0.8b"
> ```

### Step 5: Start the OpenClaw gateway

```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw gateway run --bind loopback --port 18789
```

Leave this window open.

### Step 6: Open the full Web UI

```
http://localhost:18789
```

This is the gateway-powered UI with all 52 skills active.

### Step 7: Verify

Open a new PowerShell window:

```powershell
# Check Ollama
Invoke-RestMethod http://localhost:11434/api/tags

# Check gateway
Invoke-RestMethod http://localhost:18789/health

# Test CLI chat
$env:OLLAMA_API_KEY = "ollama-local"
openclaw agent --message "hello"
```

---

## Everyday Usage

### Quick Start path (web UI only)

```powershell
# Ollama should already be running (check system tray)
cd $env:USERPROFILE\openclawo1\web
python -m http.server 8080
# Open http://localhost:8080
```

### Full Setup path (with gateway)

```powershell
# Ollama should already be running (check system tray)
cd $env:USERPROFILE\openclawo1
$env:OLLAMA_API_KEY = "ollama-local"
openclaw gateway run --bind loopback --port 18789
# Open http://localhost:18789
```

**Stopping:** Press Ctrl+C in the PowerShell window.

---

## Adding More Models

```powershell
ollama pull qwen3.5:9b           # Best quality (~8GB RAM)
ollama pull qwen3.5:2b           # Lighter (~3GB)
ollama pull qwen3.5:0.8b         # Ultra-light
ollama pull phi3:mini             # Microsoft's compact model
```

Switch model in the web UI: click gear icon, change the Model field, Save.

Or via CLI (Full Setup only):
```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw config set agents.defaults.model.primary "ollama/qwen3.5:9b"
```

---

## Adding External LLM APIs (Full Setup only)

```powershell
$env:OLLAMA_API_KEY = "ollama-local"

# OpenAI
openclaw config set models.providers.openai.apiKey "sk-your-key"
openclaw config set agents.defaults.model.primary "openai/gpt-4o"
openclaw config set agents.defaults.model.fallbacks '["ollama/qwen3.5:4b"]'

# Anthropic (Claude)
openclaw config set models.providers.anthropic.apiKey "sk-ant-your-key"
openclaw config set agents.defaults.model.primary "anthropic/claude-sonnet-4-20250514"

# Groq
openclaw config set models.providers.groq.apiKey "gsk_your-key"
openclaw config set models.providers.groq.baseUrl "https://api.groq.com/openai/v1"
openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b"
```

Or edit the config directly:
```powershell
notepad "$env:USERPROFILE\.openclaw\openclaw.json"
```

---

## Telegram Bot Integration (Full Setup only)

1. Message [@BotFather](https://t.me/BotFather) on Telegram, run `/newbot`, copy the token
2. Get your user ID from [@userinfobot](https://t.me/userinfobot)
3. Configure:
   ```powershell
   $env:OLLAMA_API_KEY = "ollama-local"
   openclaw config set channels.telegram.enabled true
   openclaw config set channels.telegram.botToken "YOUR_BOT_TOKEN"
   openclaw config set channels.telegram.allowFrom '["YOUR_USER_ID"]'
   ```
4. Restart the gateway (Ctrl+C, start again)

---

## Management Commands (Full Setup only)

```powershell
python scripts\manage.py status     # Health check + models
python scripts\manage.py models     # List/pull/remove Ollama models
python scripts\manage.py logs       # Tail logs (Ctrl+C to exit)
```

## Ports

| Port | Service | URL |
|------|---------|-----|
| **11434** | Ollama (LLM engine) | http://localhost:11434 |
| **8080** | Web UI (Quick Start) | http://localhost:8080 |
| **18789** | OpenClaw gateway (Full Setup) | http://localhost:18789 |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ollama serve` says "bind: Only one usage" | Ollama is already running. This is fine. Skip it. |
| Red dot / "Disconnected" in web UI | 1. Is Ollama running? Check system tray. 2. Did you set `OLLAMA_ORIGINS=*`? See Quick Start Step 2. 3. Did you restart Ollama after setting it? |
| CORS error in browser console | Set `OLLAMA_ORIGINS=*` (see Quick Start Step 2), restart Ollama. |
| `npm install -g openclaw` is slow | Normal — large package. Let it run. Use Quick Start in the meantime. |
| `openclaw` not recognized | npm install didn't finish, or need to reopen PowerShell. |
| `node` not found | Install: `winget install OpenJS.NodeJS.LTS`. Reopen PowerShell. |
| Model responses are generic | Click gear, change model to `qwen3.5:0.8b` (8GB) or `qwen3.5:4b` (16GB+), Save. |
| Slow first response | Normal — model loads into memory on first query. Faster after that. |
| Out of memory | Use lighter model: `ollama pull qwen3.5:2b`, change in gear settings. |
