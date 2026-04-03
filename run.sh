#!/bin/bash
#
# OpenClaw — One-command launcher
# Starts everything and opens the chat interface.
#
# Usage:
#   ./run.sh           # Start all services + open TUI chat
#   ./run.sh --cli     # Start services only (use CLI to chat)
#   ./run.sh --stop    # Stop everything
#   ./run.sh --status  # Check what's running
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export OLLAMA_API_KEY="ollama-local"
export PATH="/opt/node22/bin:/usr/local/bin:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── Token Generation ───────────────────────────────────────
generate_token() {
    # Generate a cryptographically strong random token
    if command -v openssl &>/dev/null; then
        openssl rand -hex 32
    elif [ -r /dev/urandom ]; then
        head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
    else
        # Last resort: use $RANDOM + date-based entropy
        echo "$(date +%s%N)$$$(head -c 16 /proc/sys/kernel/random/uuid 2>/dev/null || echo $RANDOM)" | sha256sum | cut -c1-64
    fi
}

# Load or generate gateway token
TOKEN_FILE="$SCRIPT_DIR/.gateway-token"
if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
    # User explicitly set a token via env var — use it
    true
elif [ -f "$TOKEN_FILE" ]; then
    # Load previously generated token
    export OPENCLAW_GATEWAY_TOKEN="$(cat "$TOKEN_FILE")"
else
    # First run: generate and persist a strong token
    NEW_TOKEN="$(generate_token)"
    echo "$NEW_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    export OPENCLAW_GATEWAY_TOKEN="$NEW_TOKEN"
    echo -e "${YELLOW}[!]${NC}  Generated new gateway token (saved to .gateway-token)"
fi

banner() {
    echo ""
    echo -e "${CYAN}+==================================================+${NC}"
    echo -e "${CYAN}|${NC}  ${GREEN}OpenClaw${NC} — AI Assistant                         ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}      Free . Local . Sandboxed                      ${CYAN}|${NC}"
    echo -e "${CYAN}+==================================================+${NC}"
    echo ""
}

cleanup_pid() {
    local pidfile="$1"
    if [ -f "$pidfile" ]; then
        local pid
        pid="$(cat "$pidfile" 2>/dev/null)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0  # Process alive
        fi
        rm -f "$pidfile"  # Stale PID file
    fi
    return 1
}

start_bridge() {
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC}  LLM Bridge already running on :11434"
        return 0
    fi

    echo -ne "${BLUE}[..]${NC}  Starting LLM bridge..."
    python3 "$SCRIPT_DIR/servers/miniclaw-bridge.py" > /tmp/miniclaw-bridge.log 2>&1 &
    local pid=$!
    echo $pid > /tmp/openclaw-bridge.pid

    for i in $(seq 1 10); do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo -e "\r${RED}[!!]${NC}  Bridge process died. Check /tmp/miniclaw-bridge.log"
            rm -f /tmp/openclaw-bridge.pid
            return 1
        fi
        if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo -e "\r${GREEN}[OK]${NC}  LLM Bridge running on :11434   "
            return 0
        fi
        sleep 1
    done
    echo -e "\r${RED}[!!]${NC}  Bridge failed to start. Check /tmp/miniclaw-bridge.log"
    rm -f /tmp/openclaw-bridge.pid
    return 1
}

start_gateway() {
    if curl -sf http://localhost:18789/health > /dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC}  Gateway already running on :18789"
        return 0
    fi

    echo -ne "${BLUE}[..]${NC}  Starting OpenClaw gateway..."
    openclaw gateway run --bind loopback --port 18789 \
        --token "$OPENCLAW_GATEWAY_TOKEN" > /tmp/openclaw-gateway.log 2>&1 &
    local pid=$!
    echo $pid > /tmp/openclaw-gateway.pid

    for i in $(seq 1 10); do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo -e "\r${YELLOW}[??]${NC}  Gateway process exited. Check /tmp/openclaw-gateway.log"
            rm -f /tmp/openclaw-gateway.pid
            return 0
        fi
        if curl -sf http://localhost:18789/health > /dev/null 2>&1; then
            echo -e "\r${GREEN}[OK]${NC}  Gateway running on :18789      "
            return 0
        fi
        sleep 1
    done
    echo -e "\r${YELLOW}[??]${NC}  Gateway may still be starting. Check /tmp/openclaw-gateway.log"
    return 0
}

stop_all() {
    echo -e "${BLUE}[..]${NC}  Stopping services..."
    for pidfile in /tmp/openclaw-bridge.pid /tmp/openclaw-gateway.pid; do
        if [ -f "$pidfile" ]; then
            local pid
            pid="$(cat "$pidfile" 2>/dev/null)"
            if [ -n "$pid" ]; then
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$pidfile"
        fi
    done
    pkill -f "miniclaw-bridge" 2>/dev/null || true
    pkill -f "openclaw gateway" 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC}  All services stopped"
}

show_status() {
    echo "-- OpenClaw Status ----------------------------------------"
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "  LLM Bridge:  ${GREEN}RUNNING${NC}  http://localhost:11434"
    else
        echo -e "  LLM Bridge:  ${RED}STOPPED${NC}"
    fi
    if curl -sf http://localhost:18789/health > /dev/null 2>&1; then
        echo -e "  Gateway:     ${GREEN}RUNNING${NC}  http://localhost:18789"
    else
        echo -e "  Gateway:     ${RED}STOPPED${NC}"
    fi
    echo ""
    echo "  Web UI:  http://localhost:18789"
    echo "  Chat:    OLLAMA_API_KEY=ollama-local openclaw agent --message 'hello' --to test"
    echo "  TUI:     OLLAMA_API_KEY=ollama-local openclaw tui"
    echo "  Stop:    ./run.sh --stop"
}

# ── Main ────────────────────────────────────────────────
case "${1:-tui}" in
    --stop|stop)
        stop_all
        ;;
    --status|status)
        show_status
        ;;
    --cli|cli)
        banner
        start_bridge
        start_gateway
        echo ""
        show_status
        ;;
    --tui|tui|"")
        banner
        start_bridge
        start_gateway
        echo ""
        echo -e "${CYAN}Opening Terminal UI...${NC}"
        echo -e "${YELLOW}Type your message and press Enter to chat.${NC}"
        echo -e "${YELLOW}Press Ctrl+C to exit.${NC}"
        echo ""
        sleep 1
        openclaw tui --token "$OPENCLAW_GATEWAY_TOKEN"
        ;;
    *)
        echo "Usage: ./run.sh [--tui|--cli|--stop|--status]"
        ;;
esac
