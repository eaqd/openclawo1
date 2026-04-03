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
export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-openclaw-sandbox-2026}"
export PATH="/opt/node22/bin:/usr/local/bin:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  🦞  ${GREEN}OpenClaw${NC} — AI Assistant                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      Free • Local • Sandboxed                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

start_bridge() {
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC}  LLM Bridge already running on :11434"
        return 0
    fi

    echo -ne "${BLUE}[..]${NC}  Starting LLM bridge..."
    python3 "$SCRIPT_DIR/servers/miniclaw-bridge.py" > /tmp/miniclaw-bridge.log 2>&1 &
    echo $! > /tmp/openclaw-bridge.pid

    for i in $(seq 1 10); do
        if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo -e "\r${GREEN}[OK]${NC}  LLM Bridge running on :11434   "
            return 0
        fi
        sleep 1
    done
    echo -e "\r${RED}[!!]${NC}  Bridge failed to start. Check /tmp/miniclaw-bridge.log"
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
    echo $! > /tmp/openclaw-gateway.pid

    for i in $(seq 1 10); do
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
            kill "$(cat "$pidfile")" 2>/dev/null || true
            rm "$pidfile"
        fi
    done
    pkill -f "miniclaw-bridge" 2>/dev/null || true
    pkill -f "openclaw gateway" 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC}  All services stopped"
}

show_status() {
    echo "── OpenClaw Status ────────────────────────────────────"
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
    echo "  Chat:  OLLAMA_API_KEY=ollama-local openclaw agent --message 'hello' --to test"
    echo "  TUI:   OLLAMA_API_KEY=ollama-local openclaw tui"
    echo "  Stop:  ./run.sh --stop"
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
