# OpenClaw Web UI Setup Guide — Local PC with Qwen 3.5

Set up OpenClaw locally on your PC with Ollama + Qwen 3.5:4b as the LLM, a web UI for chatting, room to add more models later, and optional Telegram integration.

---

## Step 1: Clone the repo

```bash
git clone https://github.com/eaqd/openclawo1.git
cd openclawo1
```

## Step 2: Run the installer

**Option A — Direct Install (recommended):**

```bash
chmod +x setup-direct.sh
./setup-direct.sh
```

This handles everything: installs Ollama, Node.js, OpenClaw, pulls the model, and configures it all. When prompted for a model, pick `qwen3.5:4b` (the default).

**Option B — Docker (sandboxed):**

```bash
python3 setup.py
```

Requires Docker + Docker Compose v2. Runs Ollama and OpenClaw in containers with memory limits (6GB Ollama, 2GB OpenClaw).

## Step 3: Pull the Qwen 3.5 model

If you used `setup-direct.sh`, it prompts you during setup. Otherwise, pull manually:

```bash
ollama pull qwen3.5:4b
```

~4GB download. Runs well on 8GB+ RAM. Supports **native tool calling** (required for OpenClaw skills).

## Step 4: Start the services

```bash
# Quick launcher (starts bridge + gateway + TUI)
./run.sh

# Or start services individually:
python3 scripts/manage.py start
```

## Step 5: Open the Web UI

Once the gateway is running, open your browser:

```
http://localhost:18789
```

The web UI features:
- Dark theme chat interface with orange accents
- Sidebar for managing conversations
- Real-time health status indicator (green/red dot)
- Code syntax highlighting

## Step 6: Verify everything works

```bash
# Check status
python3 scripts/manage.py status

# Check installed models
python3 scripts/manage.py models list

# Send a test message
OLLAMA_API_KEY=ollama-local openclaw agent --message "hello"

# Or verify via curl
curl http://localhost:11434/api/tags    # Should list qwen3.5:4b
curl http://localhost:18789/health      # Should return OK
```

---

## Adding More Models Later

```bash
# Pull additional Qwen 3.5 variants
python3 scripts/manage.py models pull qwen3.5:2b    # Lighter (~3GB)
python3 scripts/manage.py models pull qwen3.5:9b    # Best quality (~8GB)
python3 scripts/manage.py models pull qwen3.5:0.8b  # Ultra-light, phone-friendly

# Or any other Ollama-compatible model
ollama pull phi3:mini
ollama pull deepseek-coder:1.3b

# Switch the default model
openclaw config set agents.defaults.model.primary "ollama/qwen3.5:9b"
```

### Recommended Models (Qwen 3.5)

| Model | RAM | Best For |
|-------|-----|----------|
| `qwen3.5:4b` | ~4GB | Best balance for 8GB systems (default) |
| `qwen3.5:2b` | ~3GB | Lighter, phones + low-end devices |
| `qwen3.5:0.8b` | ~2GB | Ultra-light, runs on phones |
| `qwen3.5:9b` | ~8GB | Best quality (16GB+ RAM) |

## Telegram Bot Integration (Optional)

1. Message [@BotFather](https://t.me/BotFather) on Telegram → `/newbot` → copy the token
2. Get your user ID from [@userinfobot](https://t.me/userinfobot)
3. Configure:

   ```bash
   # Direct mode
   openclaw config set channels.telegram.enabled true
   openclaw config set channels.telegram.botToken "YOUR_TOKEN"
   openclaw config set channels.telegram.allowFrom '["YOUR_USER_ID"]'

   # Docker mode — add to .env file
   TELEGRAM_BOT_TOKEN=your-token
   TELEGRAM_ALLOWED_USERS=your-user-id
   ```

4. Restart: `python3 scripts/manage.py restart`

---

## Ports

| Port | Service |
|------|---------|
| **11434** | Ollama LLM engine API |
| **18789** | OpenClaw gateway + web UI |

## Key Files

| File | Purpose |
|------|---------|
| `setup-direct.sh` | Full automated installer (Ollama + OpenClaw + model) |
| `setup.py` | Docker-based setup wizard |
| `run.sh` | One-command launcher (bridge + gateway + TUI) |
| `scripts/manage.py` | Service management CLI (start/stop/status/models) |
| `web/index.html` | Standalone web chat UI |
| `config/openclaw.json5` | OpenClaw app config (model, identity, logging) |
| `config/telegram.json5` | Telegram bot config |
| `.env.example` | Environment variables template |
| `servers/miniclaw-bridge.py` | Fallback LLM bridge (pattern-matching, no GPU needed) |
| `docker-compose.yml` | Docker service definitions |

## Troubleshooting

- **Models show as "missing":** Run `ollama pull qwen3.5:4b` to download.
- **Ollama is slow / OOM:** Switch to a smaller model: `ollama pull qwen3.5:2b`
- **Gateway won't start:** Run `OLLAMA_API_KEY=ollama-local openclaw doctor` for diagnostics.
- **Telegram bot not responding:** Verify token and user ID, then `python3 scripts/manage.py restart`.
