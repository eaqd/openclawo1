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
DEFAULT_MODEL="qwen3.5:4b"

# ── Colors ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ── Model name validation ────────────────────────────────
validate_model() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9._:/-]+$ ]]; then
        fail "Invalid model name: $name"
    fi
    echo "$name"
}

echo ""
echo "+======================================================+"
echo "|        OpenClaw Direct Setup                          |"
echo "|        Free AI Assistant with Ollama                  |"
echo "+======================================================+"
echo ""

# ── Step 1: Install Ollama ───────────────────────────────
info "Step 1/5: Installing Ollama..."
if command -v ollama &>/dev/null; then
    ok "Ollama already installed: $(ollama --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo 'unknown')"
else
    info "Downloading Ollama installer..."
    INSTALLER_PATH="$(mktemp /tmp/ollama-install-XXXXXX.sh)"
    curl -fsSL https://ollama.com/install.sh -o "$INSTALLER_PATH"
    info "Review the installer at $INSTALLER_PATH if needed."
    info "Installing Ollama (requires sudo)..."
    bash "$INSTALLER_PATH"
    rm -f "$INSTALLER_PATH"
    ok "Ollama installed"
fi

# ── Step 2: Install Node.js + OpenClaw ──────────────────
info "Step 2/5: Installing Node.js and OpenClaw..."
if ! command -v node &>/dev/null; then
    info "Installing Node.js..."
    INSTALLER_PATH="$(mktemp /tmp/node-setup-XXXXXX.sh)"
    curl -fsSL https://deb.nodesource.com/setup_24.x -o "$INSTALLER_PATH"
    bash "$INSTALLER_PATH"
    rm -f "$INSTALLER_PATH"
    apt-get install -y nodejs || {
        warn "apt failed, trying nvm..."
        NVM_INSTALLER="$(mktemp /tmp/nvm-install-XXXXXX.sh)"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh -o "$NVM_INSTALLER"
        bash "$NVM_INSTALLER"
        rm -f "$NVM_INSTALLER"
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
    mkdir -p "$SCRIPT_DIR/logs"
    ollama serve > "$SCRIPT_DIR/logs/ollama.log" 2>&1 &
    sleep 3
    if curl -sf http://localhost:11434/api/tags &>/dev/null; then
        ok "Ollama server started"
    else
        fail "Could not start Ollama server. Check logs/ollama.log"
    fi
else
    ok "Ollama server already running"
fi

# Ask for model
echo ""
info "Recommended models (Qwen 3.5 — latest, with tool calling):"
echo "  1) qwen3.5:4b          — Best balance for 8GB RAM (~4GB) [default]"
echo "  2) qwen3.5:2b          — Lighter, still great (~3GB)"
echo "  3) qwen3.5:0.8b        — Ultra-light, runs on phones (~2GB)"
echo "  4) qwen3.5:9b          — Best quality if you have 16GB+ RAM (~8GB)"
echo ""
read -p "Model to pull [$DEFAULT_MODEL]: " MODEL_CHOICE
MODEL="$(validate_model "${MODEL_CHOICE:-$DEFAULT_MODEL}")"

info "Pulling $MODEL (this may take a few minutes)..."
ollama pull "$MODEL"
ok "Model $MODEL ready"

# ── Step 4: Configure OpenClaw ──────────────────────────
info "Step 4/5: Configuring OpenClaw..."

export OLLAMA_API_KEY="ollama-local"

# Create directories
mkdir -p ~/.openclaw/workspace ~/.openclaw/skills ~/.openclaw/agents/main/sessions "$SCRIPT_DIR/logs"

# Copy config file (correct schema for OpenClaw 2026.4.x)
cp "$SCRIPT_DIR/config/openclaw.json5" ~/.openclaw/openclaw.json 2>/dev/null || true

# Set model via CLI (overrides config file default)
openclaw config set gateway.mode local 2>/dev/null
openclaw config set agents.defaults.model.primary "ollama/$MODEL" 2>/dev/null
openclaw config set agents.defaults.model.reasoning false 2>/dev/null
openclaw config set models.default "ollama/$MODEL" 2>/dev/null

# Validate config
openclaw doctor --fix 2>/dev/null || true

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
    read -sp "  Bot token: " TG_TOKEN
    echo ""
    echo "  Get your user ID from @userinfobot: https://t.me/userinfobot"
    read -p "  Your user ID: " TG_USER

    if [ -n "$TG_TOKEN" ] && [ -n "$TG_USER" ]; then
        # Validate user ID is numeric
        if [[ "$TG_USER" =~ ^[0-9]+$ ]]; then
            openclaw config set channels.telegram.enabled true 2>/dev/null
            openclaw config set channels.telegram.botToken "$TG_TOKEN" 2>/dev/null
            openclaw config set "channels.telegram.allowFrom" "[\"$TG_USER\"]" 2>/dev/null
            ok "Telegram configured"
        else
            warn "Invalid user ID (must be numeric). Skipping Telegram."
        fi
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
echo "=========================================================="
echo "  OpenClaw is ready!"
echo "=========================================================="
echo ""
echo "  Start the gateway:   OLLAMA_API_KEY=ollama-local openclaw gateway"
echo "  Web UI:              http://localhost:18789"
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
echo "=========================================================="
