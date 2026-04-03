# OpenClaw Sandbox

A fully working [OpenClaw](https://github.com/openclaw/openclaw) deployment running on **Ollama** for free, local LLM inference. No API keys required. Two setup modes: **Docker** (sandboxed) or **Direct** (bare-metal).

## What You Get

- **OpenClaw 2026.4.x** AI assistant with 52 bundled skills
- **Ollama** for free local LLM inference (no cloud, no API keys)
- **Telegram bot** integration (optional)
- **Terminal UI** + Gateway web interface
- **Skills system** with ClawHub community skills
- Auto-restart, persistent data — VPS-ready

## Quick Start

### Option A: Direct Install (recommended for VPS)

```bash
git clone https://github.com/eaqd/openclawo1.git
cd openclawo1
chmod +x setup-direct.sh
./setup-direct.sh
```

This installs Ollama + OpenClaw directly, pulls a model, and configures everything.

### Option B: Docker (sandboxed)

```bash
git clone https://github.com/eaqd/openclawo1.git
cd openclawo1
python3 setup.py
```

Requires Docker with Docker Compose v2.

## Usage

```bash
# Start everything
python3 scripts/manage.py start

# Interactive terminal UI
OLLAMA_API_KEY=ollama-local openclaw tui

# Run the gateway (web interface at http://localhost:18789)
OLLAMA_API_KEY=ollama-local openclaw gateway

# Send a one-off message
OLLAMA_API_KEY=ollama-local openclaw agent --message "hello"

# Check status
python3 scripts/manage.py status

# View logs
python3 scripts/manage.py logs
```

## Management

```bash
python3 scripts/manage.py start      # Start Ollama + Gateway
python3 scripts/manage.py stop       # Stop all services
python3 scripts/manage.py restart    # Restart services
python3 scripts/manage.py status     # Health check + models
python3 scripts/manage.py logs       # Tail logs (Ctrl+C to exit)
python3 scripts/manage.py update     # Update OpenClaw
python3 scripts/manage.py models     # Manage Ollama models
```

The management CLI auto-detects whether you're running Docker or direct mode.

## Ollama Models

Default: `qwen3.5:0.8b` — ultra-light Qwen 3.5 with native tool calling, runs on 8GB RAM.
For 16GB+ systems, upgrade to `qwen3.5:4b` for better quality.

```bash
# List installed models
python3 scripts/manage.py models list

# Pull a different model
python3 scripts/manage.py models pull qwen3.5:2b
python3 scripts/manage.py models pull qwen3.5:9b

# Remove a model
python3 scripts/manage.py models remove qwen3.5:2b
```

### Recommended Models (Qwen 3.5 — March 2026)

| Model | RAM | Best For |
|-------|-----|----------|
| `qwen3.5:4b` | ~4GB | Best balance for 8GB systems (default) |
| `qwen3.5:2b` | ~3GB | Lighter, phones + low-end devices |
| `qwen3.5:0.8b` | ~2GB | Ultra-light, runs on phones |
| `qwen3.5:9b` | ~8GB | Best quality (16GB+ RAM) |

All Qwen 3.5 models support **native tool calling** (required for OpenClaw skills).

## Telegram Bot Setup

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Create a new bot with `/newbot`
3. Copy the bot token
4. Get your Telegram user ID (message [@userinfobot](https://t.me/userinfobot))
5. Configure:
   ```bash
   # Direct mode
   openclaw config set channels.telegram.enabled true
   openclaw config set channels.telegram.botToken "YOUR_TOKEN"
   openclaw config set channels.telegram.allowFrom '["YOUR_USER_ID"]'

   # Docker mode — add to .env
   TELEGRAM_BOT_TOKEN=your-token
   TELEGRAM_ALLOWED_USERS=your-user-id
   ```
6. Restart: `python3 scripts/manage.py restart`

## Custom Skills

Browse and install community skills from [ClawHub](https://github.com/openclaw/clawhub):

```bash
OLLAMA_API_KEY=ollama-local openclaw skills list          # See available skills
OLLAMA_API_KEY=ollama-local openclaw skills install <name> # Install from ClawHub
```

Or place custom skill directories in `./skills/` (each needs a `SKILL.md` file).

## Architecture

```
Direct mode:                    Docker mode:
┌──────────────────────┐       ┌─────────────────────────────────┐
│   Your Machine       │       │        Docker Network           │
│                      │       │         (claw-net)              │
│  ┌────────────────┐  │       │  ┌──────────┐  ┌────────────┐  │
│  │ Ollama :11434  │  │       │  │  Ollama   │  │  OpenClaw   │  │
│  │ (LLM engine)   │  │       │  │  :11434   │←─│  :18789    │  │
│  └───────┬────────┘  │       │  │  6GB max  │  │  2GB max   │  │
│          │           │       │  └──────────┘  └────────────┘  │
│  ┌───────┴────────┐  │       └─────────────────────────────────┘
│  │ OpenClaw :18789│  │
│  │ (AI assistant) │  │
│  └────────────────┘  │
└──────────────────────┘
```

## Configuration

OpenClaw config lives at `~/.openclaw/openclaw.json`. Edit via CLI:

```bash
openclaw config get agents.defaults.model.primary
openclaw config set agents.defaults.model.primary "ollama/phi3:mini"
openclaw doctor       # Diagnostics
openclaw doctor --fix # Auto-fix issues
```

## Troubleshooting

**Models show as "missing":** Run `ollama pull qwen2.5-coder:3b` to download.

**Ollama is slow / OOM:** Switch to a smaller model: `ollama pull deepseek-coder:1.3b`

**Gateway won't start:** Run `OLLAMA_API_KEY=ollama-local openclaw doctor` for diagnostics.

**Telegram bot not responding:** Verify token and user ID, then restart gateway.
