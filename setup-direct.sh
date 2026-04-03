#!/bin/bash
#
# OpenClaw Direct Setup (no Docker required)
# Installs Ollama + OpenClaw directly on your system.
#
# Usage:
#   chmod +x setup-direct.sh
#   ./setup-direct.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_MODEL="qwen2.5-coder:3b"

# ── Colors ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        OpenClaw Direct Setup                        ║"
echo "║        Free AI Assistant with Ollama                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Install Ollama ───────────────────────────────
info "Step 1/5: Installing Ollama..."
if command -v ollama &>/dev/null; then
    ok "Ollama already installed: $(ollama --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo 'unknown')"
else
    info "Downloading Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    ok "Ollama installed"
fi

# ── Step 2: Install Node.js + OpenClaw ──────────────────
info "Step 2/5: Installing Node.js and OpenClaw..."
if ! command -v node &>/dev/null; then
    info "Installing Node.js 24..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    apt-get install -y nodejs || {
        warn "apt failed, trying nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        nvm install 24
    }
fi
ok "Node.js $(node --version)"

if ! command -v openclaw &>/dev/null; then
    info "Installing OpenClaw..."
    npm install -g openclaw
fi
ok "OpenClaw $(openclaw --version 2>&1)"

# ── Step 3: Start Ollama & Pull Model ───────────────────
info "Step 3/5: Starting Ollama and pulling model..."

# Start Ollama server if not running
if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
    info "Starting Ollama server..."
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
    if curl -sf http://localhost:11434/api/tags &>/dev/null; then
        ok "Ollama server started"
    else
        fail "Could not start Ollama server. Check /tmp/ollama.log"
    fi
else
    ok "Ollama server already running"
fi

# Ask for model
echo ""
info "Recommended models for 8GB RAM:"
echo "  1) qwen2.5-coder:3b   — Best for coding (~2.5GB) [default]"
echo "  2) phi3:mini           — General purpose (~2.3GB)"
echo "  3) deepseek-coder:1.3b — Ultra-light coding (~1GB)"
echo "  4) llama3.2:3b         — General purpose (~2.0GB)"
echo ""
read -p "Model to pull [$DEFAULT_MODEL]: " MODEL_CHOICE
MODEL="${MODEL_CHOICE:-$DEFAULT_MODEL}"

info "Pulling $MODEL (this may take a few minutes)..."
ollama pull "$MODEL"
ok "Model $MODEL ready"

# ── Step 4: Configure OpenClaw ──────────────────────────
info "Step 4/5: Configuring OpenClaw..."

export OLLAMA_API_KEY="ollama-local"

# Set config via CLI
openclaw config set gateway.mode local 2>/dev/null
openclaw config set agents.defaults.workspace "~/.openclaw/workspace" 2>/dev/null
openclaw config set agents.defaults.model.primary "ollama/$MODEL" 2>/dev/null
openclaw config set agents.defaults.memorySearch.enabled false 2>/dev/null

mkdir -p ~/.openclaw/workspace ~/.openclaw/skills ~/.openclaw/agents/main/sessions

# Copy skills if any
if [ -d "$SCRIPT_DIR/skills" ] && [ "$(ls -A "$SCRIPT_DIR/skills" 2>/dev/null)" ]; then
    cp -rn "$SCRIPT_DIR/skills/"* ~/.openclaw/skills/ 2>/dev/null || true
fi

ok "OpenClaw configured"

# ── Step 5: Telegram (optional) ─────────────────────────
info "Step 5/5: Telegram setup (optional)"
echo ""
read -p "Set up Telegram bot? [y/N]: " SETUP_TELEGRAM
if [[ "$SETUP_TELEGRAM" =~ ^[Yy]$ ]]; then
    echo "  Get a token from @BotFather: https://t.me/BotFather"
    read -p "  Bot token: " TG_TOKEN
    echo "  Get your user ID from @userinfobot: https://t.me/userinfobot"
    read -p "  Your user ID: " TG_USER

    if [ -n "$TG_TOKEN" ] && [ -n "$TG_USER" ]; then
        openclaw config set channels.telegram.enabled true 2>/dev/null
        openclaw config set channels.telegram.botToken "$TG_TOKEN" 2>/dev/null
        openclaw config set "channels.telegram.allowFrom" "[\"$TG_USER\"]" 2>/dev/null
        ok "Telegram configured"
    else
        warn "Skipping Telegram (missing token or user ID)"
    fi
else
    info "Skipping Telegram"
fi

# ── Add OLLAMA_API_KEY to shell profile ─────────────────
PROFILE="${HOME}/.bashrc"
if ! grep -q "OLLAMA_API_KEY" "$PROFILE" 2>/dev/null; then
    echo '' >> "$PROFILE"
    echo '# OpenClaw + Ollama' >> "$PROFILE"
    echo 'export OLLAMA_API_KEY="ollama-local"' >> "$PROFILE"
    info "Added OLLAMA_API_KEY to $PROFILE"
fi

# ── Done ────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  OpenClaw is ready!"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  Start the gateway:   OLLAMA_API_KEY=ollama-local openclaw gateway"
echo "  Terminal UI:         OLLAMA_API_KEY=ollama-local openclaw tui"
echo "  Send a message:      OLLAMA_API_KEY=ollama-local openclaw agent --message 'hello'"
echo "  Check models:        OLLAMA_API_KEY=ollama-local openclaw models list"
echo "  Diagnostics:         OLLAMA_API_KEY=ollama-local openclaw doctor"
echo ""
echo "  Management:"
echo "    python3 scripts/manage.py status"
echo "    python3 scripts/manage.py logs"
echo "    python3 scripts/manage.py models"
echo ""
echo "  Ollama is running at: http://localhost:11434"
echo "  Gateway will run at:  http://localhost:18789"
echo ""
echo "══════════════════════════════════════════════════════════"
