# OpenClaw Web UI Setup Guide

Get OpenClaw running on your PC with the Qwen 3.5:4b model you already have in Ollama, view the web UI at localhost, and configure external LLM APIs later.

**Prerequisites:** Ollama installed and `qwen3.5:4b` already pulled.

---

## Step 1: Clone the repo

```bash
git clone https://github.com/eaqd/openclawo1.git
cd openclawo1
```

## Step 2: Install OpenClaw

You already have Ollama + Qwen 3.5, so you just need OpenClaw itself:

```bash
# Install Node.js if you don't have it
# (check with: node --version)
# Needs Node 20+

# Install OpenClaw globally
npm install -g openclaw
```

## Step 3: Configure OpenClaw

```bash
# Copy the environment template
cp .env.example .env

# Set the API key in your shell (add to ~/.bashrc to persist)
export OLLAMA_API_KEY="ollama-local"

# Apply the config from this repo
mkdir -p ~/.openclaw/workspace ~/.openclaw/skills
cp config/openclaw.json5 ~/.openclaw/openclaw.json
```

The config (`config/openclaw.json5`) sets:
- Primary model: `ollama/qwen3.5:4b`
- Fallbacks: `qwen3.5:2b`, `qwen3.5:0.8b`
- Gateway mode: local
- 52 bundled skills enabled

## Step 4: Start everything

```bash
# Make sure Ollama is running first
ollama serve    # skip if already running

# Then start OpenClaw (one command)
./run.sh --cli
```

Or start services manually:

```bash
export OLLAMA_API_KEY="ollama-local"

# Start the gateway (web UI)
openclaw gateway run --bind loopback --port 18789 --token openclaw-sandbox-2026
```

## Step 5: Open the Web UI in your browser

```
http://localhost:18789
```

You should see:
- Dark theme chat interface with orange accents
- Green health dot (top right) = connected to Ollama
- Sidebar for managing conversations
- Code syntax highlighting in responses

## Step 6: Verify

```bash
# Check Ollama has your model
curl http://localhost:11434/api/tags

# Check gateway is healthy
curl http://localhost:18789/health

# Send a test message via CLI
OLLAMA_API_KEY=ollama-local openclaw agent --message "hello"
```

---

## Adding External LLM APIs (OpenAI, Anthropic, etc.)

OpenClaw supports any OpenAI-compatible API. To add cloud LLMs alongside your local Qwen 3.5:

### OpenAI

```bash
# Set the API key
export OPENAI_API_KEY="sk-your-key-here"

# Add to OpenClaw config
openclaw config set models.providers.openai.apiKey "$OPENAI_API_KEY"

# Switch to GPT-4 as primary (keep Ollama as fallback)
openclaw config set agents.defaults.model.primary "openai/gpt-4o"
openclaw config set agents.defaults.model.fallbacks '["ollama/qwen3.5:4b", "ollama/qwen3.5:2b"]'
```

### Anthropic (Claude)

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key-here"

openclaw config set models.providers.anthropic.apiKey "$ANTHROPIC_API_KEY"
openclaw config set agents.defaults.model.primary "anthropic/claude-sonnet-4-20250514"
```

### Groq, Together, OpenRouter (OpenAI-compatible)

```bash
# Example: Groq
openclaw config set models.providers.groq.apiKey "gsk_your-key"
openclaw config set models.providers.groq.baseUrl "https://api.groq.com/openai/v1"
openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b"

# Example: OpenRouter
openclaw config set models.providers.openrouter.apiKey "sk-or-your-key"
openclaw config set models.providers.openrouter.baseUrl "https://openrouter.ai/api/v1"
```

### Or edit the config file directly

Edit `~/.openclaw/openclaw.json`:

```json5
{
  agents: {
    defaults: {
      model: {
        primary: "openai/gpt-4o",             // cloud when available
        fallbacks: ["ollama/qwen3.5:4b"],      // local fallback
      },
    },
  },
  models: {
    providers: {
      openai:    { apiKey: "sk-..." },
      anthropic: { apiKey: "sk-ant-..." },
      groq:      { apiKey: "gsk_...", baseUrl: "https://api.groq.com/openai/v1" },
    },
  },
}
```

After changes, restart: `python3 scripts/manage.py restart`

---

## Adding More Local Models

```bash
# Pull additional Ollama models anytime
ollama pull qwen3.5:9b           # Best quality (~8GB RAM)
ollama pull qwen3.5:2b           # Lighter (~3GB)
ollama pull phi3:mini
ollama pull deepseek-coder:1.3b

# Switch default
openclaw config set agents.defaults.model.primary "ollama/qwen3.5:9b"
```

## Telegram Bot Integration (Optional)

1. Message [@BotFather](https://t.me/BotFather) on Telegram → `/newbot` → copy the token
2. Get your user ID from [@userinfobot](https://t.me/userinfobot)
3. Configure:

   ```bash
   openclaw config set channels.telegram.enabled true
   openclaw config set channels.telegram.botToken "YOUR_TOKEN"
   openclaw config set channels.telegram.allowFrom '["YOUR_USER_ID"]'
   ```

4. Restart: `python3 scripts/manage.py restart`

---

## Management Commands

```bash
python3 scripts/manage.py start      # Start Ollama + Gateway
python3 scripts/manage.py stop       # Stop all services
python3 scripts/manage.py restart    # Restart services
python3 scripts/manage.py status     # Health check + models
python3 scripts/manage.py logs       # Tail logs
python3 scripts/manage.py models     # Manage Ollama models
```

## Ports

| Port | Service |
|------|---------|
| **11434** | Ollama LLM engine API |
| **18789** | OpenClaw gateway + web UI |

## Key Files

| File | Purpose |
|------|---------|
| `run.sh` | One-command launcher |
| `scripts/manage.py` | Service management CLI |
| `web/index.html` | Web chat UI |
| `config/openclaw.json5` | OpenClaw config (models, identity, logging) |
| `.env.example` | Environment variables template |
| `servers/miniclaw-bridge.py` | Fallback LLM bridge (no GPU needed) |

## Troubleshooting

- **Red dot in web UI:** Ollama isn't running. Start it with `ollama serve`.
- **Models show as "missing":** Run `ollama pull qwen3.5:4b`.
- **Gateway won't start:** Run `OLLAMA_API_KEY=ollama-local openclaw doctor`.
- **External API errors:** Check your API key and provider config with `openclaw config get models.providers`.
