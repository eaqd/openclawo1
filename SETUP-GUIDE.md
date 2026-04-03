# OpenClaw Setup Guide — From Qwen 3.5 to Web UI on localhost

You already have **Ollama installed** and **qwen3.5:4b pulled** on your PC.
This guide picks up right there and walks you through every step to get the
OpenClaw web UI running at `http://localhost:18789` in your browser.

---

## What you need before starting

- **Ollama** installed and working on your PC
- **qwen3.5:4b** already pulled (`ollama list` should show it)
- **Node.js 20+** (check: `node --version` — if missing, see Step 2)
- **Git** installed (check: `git --version`)
- A terminal (Command Prompt / PowerShell on Windows, Terminal on Mac/Linux)

---

## Step 1: Confirm Ollama and your model are ready

Open a terminal and run:

```bash
ollama list
```

You should see `qwen3.5:4b` in the output. If Ollama is not running yet, start it:

```bash
ollama serve
```

Leave this terminal open. Ollama needs to stay running in the background.

**Verify it's working:**

```bash
curl http://localhost:11434/api/tags
```

You should see JSON output listing your `qwen3.5:4b` model. If you see
"connection refused", go back and make sure `ollama serve` is running.

---

## Step 2: Install Node.js (skip if you already have it)

Check if you have Node.js 20 or later:

```bash
node --version
```

If it says `v20.x.x` or higher, skip to Step 3.

**If you don't have Node.js:**

- **Mac:** `brew install node`
- **Windows:** Download from https://nodejs.org (LTS version)
- **Linux (Ubuntu/Debian):**
  ```bash
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
  sudo apt-get install -y nodejs
  ```

After installing, confirm:

```bash
node --version
npm --version
```

Both should print version numbers.

---

## Step 3: Clone this repo

```bash
git clone https://github.com/eaqd/openclawo1.git
cd openclawo1
```

You should now be inside the `openclawo1` folder. Confirm:

```bash
ls
```

You should see files like `run.sh`, `scripts/`, `web/`, `config/`, etc.

---

## Step 4: Install OpenClaw

```bash
npm install -g openclaw
```

This installs the OpenClaw AI assistant globally. Verify:

```bash
openclaw --version
```

It should print a version number like `2026.4.x`.

---

## Step 5: Configure OpenClaw to use your Qwen 3.5 model

**5a. Set the environment variable:**

This tells OpenClaw how to talk to your local Ollama:

```bash
export OLLAMA_API_KEY="ollama-local"
```

To make this permanent (so you don't have to type it every time):

- **Mac/Linux:** Add it to your shell profile:
  ```bash
  echo 'export OLLAMA_API_KEY="ollama-local"' >> ~/.bashrc
  source ~/.bashrc
  ```
  (Use `~/.zshrc` instead if you're on macOS with zsh.)

- **Windows (PowerShell):**
  ```powershell
  [System.Environment]::SetEnvironmentVariable("OLLAMA_API_KEY", "ollama-local", "User")
  ```

**5b. Copy the config files:**

```bash
mkdir -p ~/.openclaw/workspace ~/.openclaw/skills
cp config/openclaw.json5 ~/.openclaw/openclaw.json
```

This configures OpenClaw with:
- **Primary model:** `ollama/qwen3.5:4b` (your local model)
- **Fallbacks:** `qwen3.5:2b`, `qwen3.5:0.8b` (if you pull them later)
- **52 bundled skills** enabled
- **Gateway mode:** local (everything stays on your machine)

**5c. Copy the environment file:**

```bash
cp .env.example .env
```

---

## Step 6: Start OpenClaw

Make sure you're in the `openclawo1` folder, then:

```bash
chmod +x run.sh
./run.sh --cli
```

You should see output like:

```
+==================================================+
|  OpenClaw — AI Assistant                         |
|      Free . Local . Sandboxed                    |
+==================================================+

[OK]  LLM Bridge running on :11434
[OK]  Gateway running on :18789

-- OpenClaw Status ----------------------------------------
  LLM Bridge:  RUNNING  http://localhost:11434
  Gateway:     RUNNING  http://localhost:18789

  Web UI:  http://localhost:18789
```

**Important:** If the bridge says "already running" because your Ollama is on
port 11434, that's perfect — it detected your real Ollama and skipped the
bridge. That means your actual Qwen 3.5 model will be used.

**On Windows**, if `./run.sh` doesn't work, start it manually:

```bash
set OLLAMA_API_KEY=ollama-local
openclaw gateway run --bind loopback --port 18789
```

---

## Step 7: Open the Web UI in your browser

Open your browser (Chrome, Firefox, Edge, Safari) and go to:

```
http://localhost:18789
```

**What you should see:**

1. A dark-themed chat interface with an orange accent color
2. A **green dot** in the top-right corner that says "Connected"
   (If it's red, Ollama isn't running — go back to Step 1)
3. A sidebar on the left with "Sessions" and "Skills"
4. A welcome screen with quick-start chips: "Say hello", "Write code", "Explain concept"
5. A text input box at the bottom to type messages

**Try it out:**

- Click "Say hello" or type a message and press Enter
- The response comes from your local Qwen 3.5:4b model — no cloud, no API key needed

---

## Step 8: Verify everything is connected

Open a new terminal and run these checks:

```bash
# 1. Is Ollama running with your model?
curl http://localhost:11434/api/tags
# Should show qwen3.5:4b

# 2. Is the gateway healthy?
curl http://localhost:18789/health
# Should return {"status":"ok", ...}

# 3. Can OpenClaw talk to the model?
OLLAMA_API_KEY=ollama-local openclaw agent --message "Say hello in one sentence"
# Should get a response from Qwen 3.5
```

If all three work, you're fully set up.

---

## Step 9: Configure the Web UI settings (optional)

Click the **gear icon** in the top-right corner of the web UI to open settings:

- **Ollama API URL:** `http://localhost:11434` (default, don't change)
- **Gateway Token:** Leave blank (auto-generated on first run)
- **Model:** Change to `qwen3.5:4b` to use your real model instead of "miniclaw"

Click "Save & Connect". The status dot should turn green.

---

## Everyday Usage

**Starting OpenClaw** (after first setup):

```bash
# Terminal 1: Make sure Ollama is running
ollama serve

# Terminal 2: Start OpenClaw
cd openclawo1
./run.sh --cli

# Then open http://localhost:18789 in your browser
```

**Stopping:**

```bash
./run.sh --stop
```

**Quick status check:**

```bash
./run.sh --status
```

---

## Adding More Models Later

Pull any Ollama model — OpenClaw picks them up automatically:

```bash
ollama pull qwen3.5:9b           # Best quality (~8GB RAM needed)
ollama pull qwen3.5:2b           # Lighter (~3GB)
ollama pull qwen3.5:0.8b         # Ultra-light, runs on phones
ollama pull phi3:mini             # Microsoft's compact model
ollama pull deepseek-coder:1.3b  # Lightweight coding model
```

Switch the default model:

```bash
OLLAMA_API_KEY=ollama-local openclaw config set agents.defaults.model.primary "ollama/qwen3.5:9b"
python3 scripts/manage.py restart
```

---

## Adding External LLM APIs (OpenAI, Anthropic, etc.)

You can add cloud LLMs alongside your local model. OpenClaw supports any
OpenAI-compatible API:

**OpenAI:**
```bash
OLLAMA_API_KEY=ollama-local openclaw config set models.providers.openai.apiKey "sk-your-key"
OLLAMA_API_KEY=ollama-local openclaw config set agents.defaults.model.primary "openai/gpt-4o"
OLLAMA_API_KEY=ollama-local openclaw config set agents.defaults.model.fallbacks '["ollama/qwen3.5:4b"]'
```

**Anthropic (Claude):**
```bash
OLLAMA_API_KEY=ollama-local openclaw config set models.providers.anthropic.apiKey "sk-ant-your-key"
OLLAMA_API_KEY=ollama-local openclaw config set agents.defaults.model.primary "anthropic/claude-sonnet-4-20250514"
```

**Groq / OpenRouter:**
```bash
OLLAMA_API_KEY=ollama-local openclaw config set models.providers.groq.apiKey "gsk_your-key"
OLLAMA_API_KEY=ollama-local openclaw config set models.providers.groq.baseUrl "https://api.groq.com/openai/v1"
OLLAMA_API_KEY=ollama-local openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b"
```

**Or edit the config file directly** at `~/.openclaw/openclaw.json`:

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

After any API changes: `python3 scripts/manage.py restart`

---

## Telegram Bot Integration (Optional)

1. Message [@BotFather](https://t.me/BotFather) on Telegram, run `/newbot`, copy the token
2. Get your user ID from [@userinfobot](https://t.me/userinfobot)
3. Configure:
   ```bash
   OLLAMA_API_KEY=ollama-local openclaw config set channels.telegram.enabled true
   OLLAMA_API_KEY=ollama-local openclaw config set channels.telegram.botToken "YOUR_TOKEN"
   OLLAMA_API_KEY=ollama-local openclaw config set channels.telegram.allowFrom '["YOUR_USER_ID"]'
   ```
4. Restart: `python3 scripts/manage.py restart`
5. Message your bot on Telegram — it responds using your local Qwen 3.5 model

---

## Management Commands

```bash
python3 scripts/manage.py start      # Start Ollama + Gateway
python3 scripts/manage.py stop       # Stop all services
python3 scripts/manage.py restart    # Restart services
python3 scripts/manage.py status     # Health check + models
python3 scripts/manage.py logs       # Tail logs (Ctrl+C to exit)
python3 scripts/manage.py models     # Manage Ollama models
```

## Ports

| Port | Service | URL |
|------|---------|-----|
| **11434** | Ollama (LLM engine) | http://localhost:11434 |
| **18789** | OpenClaw (web UI + gateway) | http://localhost:18789 |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Red dot in web UI | Ollama isn't running. Open a terminal, run `ollama serve` |
| "Connection refused" on :11434 | Same as above — Ollama needs to be running |
| "Connection refused" on :18789 | Gateway isn't running. Run `./run.sh --cli` |
| Model responses are generic | Click gear icon in web UI, change model to `qwen3.5:4b` |
| Gateway token error | Delete `.gateway-token` file and restart: `./run.sh --stop && ./run.sh --cli` |
| Slow responses | Normal for first query (model loading). Subsequent queries are faster |
| Out of memory | Switch to lighter model: `ollama pull qwen3.5:2b` |
| External API not working | Check key: `OLLAMA_API_KEY=ollama-local openclaw config get models.providers` |
