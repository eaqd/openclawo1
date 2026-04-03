# OpenClaw Sandbox

A fully sandboxed [OpenClaw](https://github.com/openclaw/openclaw) deployment running on **Ollama** for free, local LLM inference. No API keys required.

## What You Get

- **OpenClaw** AI assistant in a Docker container
- **Ollama** running locally with `qwen2.5-coder:3b` (optimized for 8GB RAM)
- **Telegram bot** integration (optional)
- **Terminal/CLI** access
- **Skills system** with support for custom and community skills
- Auto-restart, persistent data, resource limits — VPS-ready

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose v2
- Python 3.8+
- 8GB RAM minimum (6GB allocated to Ollama)

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/eaqd/openclawo1.git
cd openclawo1

# 2. Run setup (checks Docker, configures .env, builds, pulls models)
python3 setup.py

# 3. Interact with OpenClaw
docker compose exec openclaw openclaw
```

## Management

```bash
python3 scripts/manage.py start      # Start all services
python3 scripts/manage.py stop       # Stop all services
python3 scripts/manage.py restart    # Restart services
python3 scripts/manage.py status     # Health check + resource usage
python3 scripts/manage.py logs       # Tail logs (Ctrl+C to exit)
python3 scripts/manage.py shell      # Shell into OpenClaw container
python3 scripts/manage.py update     # Update to latest OpenClaw
python3 scripts/manage.py models     # Manage Ollama models
```

## Ollama Models

Default: `qwen2.5-coder:3b` — best coding model for low-end hardware.

```bash
# List installed models
python3 scripts/manage.py models list

# Pull a different model
python3 scripts/manage.py models pull phi3:mini
python3 scripts/manage.py models pull llama3.2:3b
python3 scripts/manage.py models pull deepseek-coder:1.3b

# Remove a model
python3 scripts/manage.py models remove phi3:mini
```

### Recommended Models (8GB RAM)

| Model | Size | Best For |
|-------|------|----------|
| `qwen2.5-coder:3b` | ~2.5GB | Coding tasks (default) |
| `phi3:mini` | ~2.3GB | General purpose |
| `llama3.2:3b` | ~2.0GB | General purpose |
| `deepseek-coder:1.3b` | ~1GB | Lightweight coding |

## Telegram Bot Setup

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Create a new bot with `/newbot`
3. Copy the bot token
4. Get your Telegram user ID (message [@userinfobot](https://t.me/userinfobot))
5. Add to `.env`:
   ```
   TELEGRAM_BOT_TOKEN=your-bot-token-here
   TELEGRAM_ALLOWED_USERS=your-user-id
   ```
6. Restart: `python3 scripts/manage.py restart`

## Custom Skills

Place skill directories in `./skills/`. Each skill needs a `SKILL.md` file:

```
skills/
  my-skill/
    SKILL.md
    (optional scripts, data files)
```

Browse community skills at [ClawHub](https://github.com/openclaw/clawhub).

## Architecture

```
┌─────────────────────────────────────────────┐
│                Docker Network               │
│                 (claw-net)                   │
│                                             │
│  ┌──────────────┐    ┌──────────────────┐   │
│  │   Ollama      │    │    OpenClaw       │   │
│  │  (LLM engine) │◄───│  (AI assistant)  │   │
│  │  :11434       │    │                  │   │
│  │  6GB RAM max  │    │  4GB RAM max     │   │
│  └──────────────┘    └──────────────────┘   │
│         │                     │              │
│    ollama-data          openclaw-config      │
│    (models)            (config + workspace)  │
└─────────────────────────────────────────────┘
```

## Troubleshooting

**Ollama is slow or OOM:**
Switch to a smaller model: `python3 scripts/manage.py models pull deepseek-coder:1.3b`

**Container won't start:**
Check logs: `docker compose logs ollama` or `docker compose logs openclaw`

**Model download stuck:**
Restart Ollama: `docker compose restart ollama`, then re-pull the model.

**Telegram bot not responding:**
Verify your bot token and user ID in `.env`, then restart.
