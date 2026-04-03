# OpenClaw Setup Guide — Windows PowerShell

You have **Ollama running** and **qwen3.5:4b pulled** on your Windows PC.
This guide walks you through every step in **PowerShell** to get the OpenClaw
web UI running at `http://localhost:18789` in your browser.

> If you tried `ollama serve` and got "bind: Only one usage of each socket
> address" — that means **Ollama is already running**. That's good. Skip
> straight to Step 1.

---

## Step 1: Confirm Ollama and your model are ready

Open **PowerShell** and run:

```powershell
ollama list
```

You should see `qwen3.5:4b` in the list. Now verify the API is responding:

```powershell
Invoke-RestMethod http://localhost:11434/api/tags
```

You should see output showing your model. If this works, Ollama is running
and ready. **Do not run `ollama serve` again** — it's already running.

---

## Step 2: Check if you have Node.js

```powershell
node --version
```

You need **v20 or higher**. If it prints `v20.x.x`, `v22.x.x`, etc., skip to Step 3.

**If Node.js is missing or too old:**

Option A — Using winget (easiest):
```powershell
winget install OpenJS.NodeJS.LTS
```

Option B — Manual download:
Go to https://nodejs.org and download the **LTS** installer. Run it, accept
defaults, and restart PowerShell when done.

After installing, **close and reopen PowerShell**, then verify:

```powershell
node --version
npm --version
```

Both should print version numbers.

---

## Step 3: Clone the repo

Pick a folder where you want to keep this project. For example, your home
directory:

```powershell
cd $env:USERPROFILE
git clone https://github.com/eaqd/openclawo1.git
cd openclawo1
```

Verify you're in the right place:

```powershell
dir
```

You should see files like `run.sh`, `scripts`, `web`, `config`, etc.

---

## Step 4: Install OpenClaw

```powershell
npm install -g openclaw
```

Wait for it to finish (may take a minute). Then verify:

```powershell
openclaw --version
```

It should print a version number like `2026.4.x`.

---

## Step 5: Set the environment variable

OpenClaw needs this variable to talk to your local Ollama.

**For this PowerShell session (temporary):**

```powershell
$env:OLLAMA_API_KEY = "ollama-local"
```

**To make it permanent (persists after restarting PowerShell/PC):**

```powershell
[System.Environment]::SetEnvironmentVariable("OLLAMA_API_KEY", "ollama-local", "User")
```

> After setting it permanently, close and reopen PowerShell for it to take
> effect. Or just keep using `$env:OLLAMA_API_KEY = "ollama-local"` at the
> start of each session until you restart.

---

## Step 6: Copy the config files

These commands create the OpenClaw config directory and copy the settings
from this repo:

```powershell
# Create the config directories
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw\workspace"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw\skills"

# Copy the OpenClaw config (sets qwen3.5:4b as your model)
Copy-Item config\openclaw.json5 "$env:USERPROFILE\.openclaw\openclaw.json"

# Copy the environment file
Copy-Item .env.example .env
```

This configures OpenClaw with:
- **Primary model:** `ollama/qwen3.5:4b` (your local Qwen 3.5)
- **Fallbacks:** `qwen3.5:2b`, `qwen3.5:0.8b` (if you pull them later)
- **52 bundled skills** enabled
- **Gateway mode:** local (everything stays on your machine)

---

## Step 7: Start the OpenClaw gateway

Make sure the env var is set, then start the gateway:

```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw gateway run --bind loopback --port 18789
```

**Leave this PowerShell window open.** The gateway needs to keep running.

You should see output indicating the gateway has started. If you see errors,
check the Troubleshooting section below.

---

## Step 8: Open the Web UI in your browser

Open **Chrome**, **Edge**, **Firefox**, or any browser and go to:

```
http://localhost:18789
```

**What you should see:**

1. A dark-themed chat interface with an orange accent color
2. A **green dot** in the top-right corner that says "Connected"
3. A sidebar on the left with "Sessions" and "Skills"
4. A welcome screen with chips: "Say hello", "Write code", "Explain concept"
5. A text input box at the bottom

> **If the dot is red** ("Disconnected"), click the gear icon and make sure
> the Ollama API URL is set to `http://localhost:11434`. Click "Save & Connect".

---

## Step 9: Set the model in the Web UI

Click the **gear icon** (top-right corner) to open settings:

1. **Ollama API URL:** `http://localhost:11434` (should already be set)
2. **Gateway Token:** Leave blank
3. **Model:** Change this from `miniclaw` to `qwen3.5:4b`

Click **"Save & Connect"**. The dot should turn green.

---

## Step 10: Test it

Type a message in the chat box and press Enter. For example:

- "Hello! What can you help me with?"
- "Write me a fibonacci function in Python"
- "Explain what a REST API is"

The response comes from your **local Qwen 3.5:4b model** — no internet, no
cloud, no API keys needed.

---

## Step 11: Verify everything (optional)

Open a **new PowerShell window** (keep the gateway running in the other one):

```powershell
# 1. Is Ollama running with your model?
Invoke-RestMethod http://localhost:11434/api/tags
# Should show qwen3.5:4b in the models list

# 2. Is the OpenClaw gateway healthy?
Invoke-RestMethod http://localhost:18789/health
# Should return status: ok

# 3. Can OpenClaw talk to the model via CLI?
$env:OLLAMA_API_KEY = "ollama-local"
openclaw agent --message "Say hello in one sentence"
# Should get a response from Qwen 3.5
```

If all three work, you're fully set up.

---

## Everyday Usage

**Starting OpenClaw** (every time you want to use it):

Ollama usually starts automatically with Windows (runs as a service in the
system tray). If not, open a PowerShell window and run `ollama serve`.

Then open a PowerShell window:

```powershell
cd $env:USERPROFILE\openclawo1
$env:OLLAMA_API_KEY = "ollama-local"
openclaw gateway run --bind loopback --port 18789
```

Then open your browser to `http://localhost:18789`.

**Stopping:**

Press **Ctrl+C** in the PowerShell window where the gateway is running.

**Quick test without the web UI:**

```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw agent --message "hello"
```

---

## Adding More Models Later

Pull any Ollama model — they show up in OpenClaw automatically:

```powershell
ollama pull qwen3.5:9b           # Best quality (~8GB RAM needed)
ollama pull qwen3.5:2b           # Lighter (~3GB)
ollama pull qwen3.5:0.8b         # Ultra-light
ollama pull phi3:mini             # Microsoft's compact model
```

Switch the default model:

```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw config set agents.defaults.model.primary "ollama/qwen3.5:9b"
```

Then restart the gateway (Ctrl+C, then start it again).

You can also switch models in the **web UI gear icon** without restarting.

---

## Adding External LLM APIs (OpenAI, Anthropic, etc.)

Add cloud LLMs alongside your local model. Your Qwen 3.5 stays as a fallback.

**OpenAI:**
```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw config set models.providers.openai.apiKey "sk-your-key-here"
openclaw config set agents.defaults.model.primary "openai/gpt-4o"
openclaw config set agents.defaults.model.fallbacks '["ollama/qwen3.5:4b"]'
```

**Anthropic (Claude):**
```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw config set models.providers.anthropic.apiKey "sk-ant-your-key-here"
openclaw config set agents.defaults.model.primary "anthropic/claude-sonnet-4-20250514"
```

**Groq (fast inference):**
```powershell
$env:OLLAMA_API_KEY = "ollama-local"
openclaw config set models.providers.groq.apiKey "gsk_your-key"
openclaw config set models.providers.groq.baseUrl "https://api.groq.com/openai/v1"
openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b"
```

**Or edit the config file directly:**

Open this file in Notepad or VS Code:

```powershell
notepad "$env:USERPROFILE\.openclaw\openclaw.json"
```

Add a `models.providers` section:

```json5
{
  agents: {
    defaults: {
      model: {
        primary: "openai/gpt-4o",
        fallbacks: ["ollama/qwen3.5:4b"],
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

After any config changes, restart the gateway (Ctrl+C, start again).

---

## Telegram Bot Integration (Optional)

1. Message [@BotFather](https://t.me/BotFather) on Telegram, run `/newbot`, copy the token
2. Get your user ID from [@userinfobot](https://t.me/userinfobot)
3. Configure in PowerShell:
   ```powershell
   $env:OLLAMA_API_KEY = "ollama-local"
   openclaw config set channels.telegram.enabled true
   openclaw config set channels.telegram.botToken "YOUR_BOT_TOKEN"
   openclaw config set channels.telegram.allowFrom '["YOUR_USER_ID"]'
   ```
4. Restart the gateway
5. Message your bot on Telegram — it responds using your local model

---

## Management Commands

```powershell
python scripts\manage.py status     # Health check + models
python scripts\manage.py models     # List/pull/remove Ollama models
python scripts\manage.py logs       # Tail logs (Ctrl+C to exit)
```

## Ports

| Port | Service | URL |
|------|---------|-----|
| **11434** | Ollama (LLM engine) | http://localhost:11434 |
| **18789** | OpenClaw (web UI + gateway) | http://localhost:18789 |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ollama serve` says "bind: Only one usage" | **Ollama is already running.** This is fine. Skip `ollama serve`. |
| Red dot in web UI | Ollama isn't running. Check system tray for Ollama icon, or run `ollama serve` in a new PowerShell. |
| "Connection refused" on :11434 | Same — Ollama not running. |
| "Connection refused" on :18789 | Gateway not running. Start it with `openclaw gateway run --bind loopback --port 18789` |
| `openclaw` not found | Run `npm install -g openclaw` again. Close and reopen PowerShell. |
| `node` not found | Install Node.js: `winget install OpenJS.NodeJS.LTS`. Reopen PowerShell. |
| Model responses are generic / "miniclaw" | Click gear icon in web UI, change model to `qwen3.5:4b`, click Save. |
| Slow first response | Normal — the model loads into memory on first query. Subsequent ones are faster. |
| Out of memory | Switch to lighter model: `ollama pull qwen3.5:2b` and change model in web UI settings. |
| Config changes not taking effect | Restart the gateway: Ctrl+C then start again. |
