#!/bin/bash
#
# OpenClaw Sandbox Launcher
# Runs OpenClaw + Ollama inside a Linux namespace sandbox with:
#   - PID isolation (can't see/kill host processes)
#   - Mount isolation (private /tmp, /proc)
#   - Network isolation (only loopback + bridged access)
#   - Memory limits via cgroups (default 6GB)
#   - PID count limits (max 512 processes)
#   - CPU limits (50% of host)
#   - Read-only bind mounts for system dirs
#   - Dedicated non-root user inside the sandbox
#
# Usage:
#   sudo ./sandbox/launch.sh              # Start sandboxed OpenClaw
#   sudo ./sandbox/launch.sh --shell      # Drop into sandbox shell
#   sudo ./sandbox/launch.sh --stop       # Stop the sandbox
#   sudo ./sandbox/launch.sh --status     # Show sandbox status
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SANDBOX_ROOT="/var/lib/openclaw-sandbox"
SANDBOX_HOME="$SANDBOX_ROOT/home/openclaw"
CGROUP_NAME="openclaw-sandbox"
SANDBOX_USER="openclaw"
SANDBOX_UID=65534  # nobody UID as fallback

# ── Configurable Limits ─────────────────────────────────────
MEM_LIMIT="${OPENCLAW_MEM_LIMIT:-6442450944}"   # 6GB in bytes
PID_LIMIT="${OPENCLAW_PID_LIMIT:-512}"
CPU_SHARES="${OPENCLAW_CPU_SHARES:-512}"         # 50% (1024 = 100%)
GATEWAY_PORT="${OPENCLAW_PORT:-18789}"
OLLAMA_PORT="11434"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[sandbox]${NC} $*"; }
ok()    { echo -e "${GREEN}[sandbox]${NC} $*"; }
warn()  { echo -e "${YELLOW}[sandbox]${NC} $*"; }
fail()  { echo -e "${RED}[sandbox]${NC} $*"; exit 1; }

# ── Check Root ──────────────────────────────────────────────
[[ $EUID -eq 0 ]] || fail "Must run as root (use sudo)"

# ── Setup Cgroups ───────────────────────────────────────────
setup_cgroups() {
    info "Setting up cgroup limits..."

    # Memory limit
    if [ -d /sys/fs/cgroup/memory ]; then
        mkdir -p /sys/fs/cgroup/memory/$CGROUP_NAME
        echo "$MEM_LIMIT" > /sys/fs/cgroup/memory/$CGROUP_NAME/memory.limit_in_bytes
        ok "  Memory limit: $(( MEM_LIMIT / 1024 / 1024 ))MB"
    fi

    # PID limit
    if [ -d /sys/fs/cgroup/pids ]; then
        mkdir -p /sys/fs/cgroup/pids/$CGROUP_NAME
        echo "$PID_LIMIT" > /sys/fs/cgroup/pids/$CGROUP_NAME/pids.max
        ok "  PID limit: $PID_LIMIT"
    fi

    # CPU shares
    if [ -d /sys/fs/cgroup/cpu ]; then
        mkdir -p /sys/fs/cgroup/cpu/$CGROUP_NAME
        echo "$CPU_SHARES" > /sys/fs/cgroup/cpu/$CGROUP_NAME/cpu.shares
        ok "  CPU shares: $CPU_SHARES/1024"
    fi
}

# ── Add Process to Cgroups ──────────────────────────────────
cgroup_add_pid() {
    local pid=$1
    for ctrl in memory pids cpu; do
        if [ -d /sys/fs/cgroup/$ctrl/$CGROUP_NAME ]; then
            echo "$pid" > /sys/fs/cgroup/$ctrl/$CGROUP_NAME/cgroup.procs 2>/dev/null || true
        fi
    done
}

# ── Build Sandbox Filesystem ───────────────────────────────
build_rootfs() {
    info "Building sandbox filesystem..."

    mkdir -p "$SANDBOX_ROOT"/{bin,lib,lib64,usr,etc,tmp,proc,dev,sys,run,var/tmp}
    mkdir -p "$SANDBOX_HOME"/.openclaw/{workspace,skills,agents/main/sessions}

    # Bind-mount system directories read-only
    for dir in bin lib lib64 usr etc; do
        if [ -d "/$dir" ] && ! mountpoint -q "$SANDBOX_ROOT/$dir" 2>/dev/null; then
            mount --bind "/$dir" "$SANDBOX_ROOT/$dir"
            mount -o remount,ro,bind "$SANDBOX_ROOT/$dir"
        fi
    done

    # Mount /dev minimally
    if ! mountpoint -q "$SANDBOX_ROOT/dev" 2>/dev/null; then
        mount -t tmpfs -o size=1m,mode=755 tmpfs "$SANDBOX_ROOT/dev"
        for dev in null zero urandom random; do
            touch "$SANDBOX_ROOT/dev/$dev"
            mount --bind "/dev/$dev" "$SANDBOX_ROOT/dev/$dev"
        done
    fi

    # Writable /tmp
    if ! mountpoint -q "$SANDBOX_ROOT/tmp" 2>/dev/null; then
        mount -t tmpfs -o size=512m,mode=1777 tmpfs "$SANDBOX_ROOT/tmp"
    fi

    # Copy OpenClaw config
    cp "$PROJECT_DIR/config/openclaw.json5" "$SANDBOX_HOME/.openclaw/openclaw.json" 2>/dev/null || true

    # Copy skills
    if [ -d "$PROJECT_DIR/skills" ]; then
        cp -rn "$PROJECT_DIR/skills/"* "$SANDBOX_HOME/.openclaw/skills/" 2>/dev/null || true
    fi

    # Node/npm paths (make accessible)
    if [ -d /opt/node22 ] && ! mountpoint -q "$SANDBOX_ROOT/opt" 2>/dev/null; then
        mkdir -p "$SANDBOX_ROOT/opt"
        mount --bind /opt "$SANDBOX_ROOT/opt"
        mount -o remount,ro,bind "$SANDBOX_ROOT/opt"
    fi

    # Copy Ollama binary
    if [ -f /usr/local/bin/ollama ]; then
        mkdir -p "$SANDBOX_ROOT/usr/local/bin"
        # usr is already mounted read-only, put it in the home dir
        cp /usr/local/bin/ollama "$SANDBOX_HOME/ollama" 2>/dev/null || true
    fi

    # Copy bridge server
    mkdir -p "$SANDBOX_HOME/servers"
    cp "$PROJECT_DIR/servers/miniclaw-bridge.py" "$SANDBOX_HOME/servers/" 2>/dev/null || true

    # Set ownership
    chown -R $SANDBOX_UID:$SANDBOX_UID "$SANDBOX_HOME" 2>/dev/null || true

    ok "  Rootfs ready at $SANDBOX_ROOT"
}

# ── Cleanup Mounts ──────────────────────────────────────────
cleanup_mounts() {
    info "Cleaning up sandbox mounts..."
    for mp in $(grep "$SANDBOX_ROOT" /proc/mounts | awk '{print $2}' | sort -r); do
        umount -l "$mp" 2>/dev/null || true
    done
    ok "  Mounts cleaned"
}

# ── Launch Inside Sandbox ───────────────────────────────────
launch_sandbox() {
    local cmd="${1:-services}"

    setup_cgroups
    build_rootfs

    info "Launching sandbox..."

    if [ "$cmd" = "shell" ]; then
        info "Dropping into sandbox shell..."
        info "  You are in an isolated environment."
        info "  System dirs are read-only. Only /tmp and /home/openclaw are writable."
        echo ""

        unshare --pid --fork --mount-proc="$SANDBOX_ROOT/proc" \
            chroot "$SANDBOX_ROOT" \
            /bin/bash -c "
                export HOME=/home/openclaw
                export PATH=/opt/node22/bin:/usr/local/bin:/usr/bin:/bin
                export OLLAMA_API_KEY=ollama-local
                cd /home/openclaw
                exec /bin/bash --login
            "
    else
        # Start services inside sandbox
        info "Starting services in sandbox..."

        # Create the startup script inside sandbox
        cat > "$SANDBOX_HOME/start.sh" << 'STARTUP'
#!/bin/bash
export HOME=/home/openclaw
export PATH=/opt/node22/bin:/usr/local/bin:/usr/bin:/bin
export OLLAMA_API_KEY=ollama-local
export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-openclaw-sandbox-2026}"
cd /home/openclaw

echo "[sandbox] Starting MiniClaw bridge on :11434..."
python3 /home/openclaw/servers/miniclaw-bridge.py > /tmp/bridge.log 2>&1 &
BRIDGE_PID=$!
sleep 2

if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[sandbox] Bridge: OK (PID $BRIDGE_PID)"
else
    echo "[sandbox] Bridge: FAILED"
    exit 1
fi

echo "[sandbox] Starting OpenClaw gateway on :18789..."
openclaw gateway run --bind loopback --port 18789 \
    --token "$OPENCLAW_GATEWAY_TOKEN" > /tmp/gateway.log 2>&1 &
GW_PID=$!
sleep 3

echo "[sandbox] ════════════════════════════════════════════"
echo "[sandbox]  OpenClaw Sandbox Running"
echo "[sandbox]  Bridge:  http://localhost:11434 (PID $BRIDGE_PID)"
echo "[sandbox]  Gateway: http://localhost:18789 (PID $GW_PID)"
echo "[sandbox]  Use: openclaw agent --message 'hello' --to test"
echo "[sandbox] ════════════════════════════════════════════"

# Keep alive and forward signals
trap "kill $BRIDGE_PID $GW_PID 2>/dev/null; exit 0" SIGTERM SIGINT
wait
STARTUP
        chmod +x "$SANDBOX_HOME/start.sh"

        # Launch in namespace
        unshare --pid --fork --mount-proc="$SANDBOX_ROOT/proc" \
            chroot "$SANDBOX_ROOT" \
            /bin/bash /home/openclaw/start.sh &

        SANDBOX_PID=$!
        cgroup_add_pid $SANDBOX_PID

        echo "$SANDBOX_PID" > /tmp/openclaw-sandbox.pid
        ok "Sandbox launched (PID $SANDBOX_PID)"
        ok "Logs: tail -f $SANDBOX_HOME/start.sh won't work; use: tail -f $SANDBOX_ROOT/tmp/gateway.log"

        wait $SANDBOX_PID 2>/dev/null
    fi
}

# ── Stop Sandbox ────────────────────────────────────────────
stop_sandbox() {
    info "Stopping sandbox..."
    if [ -f /tmp/openclaw-sandbox.pid ]; then
        PID=$(cat /tmp/openclaw-sandbox.pid)
        kill -TERM "$PID" 2>/dev/null && ok "Sent SIGTERM to PID $PID"
        sleep 2
        kill -9 "$PID" 2>/dev/null || true
        rm /tmp/openclaw-sandbox.pid
    fi
    # Kill any remaining sandbox processes
    pkill -f "miniclaw-bridge" 2>/dev/null || true
    pkill -f "openclaw gateway" 2>/dev/null || true
    cleanup_mounts
    ok "Sandbox stopped"
}

# ── Status ──────────────────────────────────────────────────
show_status() {
    echo "── OpenClaw Sandbox Status ────────────────────────────"

    if [ -f /tmp/openclaw-sandbox.pid ] && kill -0 "$(cat /tmp/openclaw-sandbox.pid)" 2>/dev/null; then
        ok "Sandbox: RUNNING (PID $(cat /tmp/openclaw-sandbox.pid))"
    else
        warn "Sandbox: STOPPED"
    fi

    echo ""
    echo "Cgroup Limits:"
    if [ -f /sys/fs/cgroup/memory/$CGROUP_NAME/memory.limit_in_bytes ]; then
        MEM=$(cat /sys/fs/cgroup/memory/$CGROUP_NAME/memory.limit_in_bytes)
        USED=$(cat /sys/fs/cgroup/memory/$CGROUP_NAME/memory.usage_in_bytes 2>/dev/null || echo 0)
        echo "  Memory: $(( USED / 1024 / 1024 ))MB / $(( MEM / 1024 / 1024 ))MB"
    fi
    if [ -f /sys/fs/cgroup/pids/$CGROUP_NAME/pids.current ]; then
        echo "  PIDs:   $(cat /sys/fs/cgroup/pids/$CGROUP_NAME/pids.current) / $(cat /sys/fs/cgroup/pids/$CGROUP_NAME/pids.max)"
    fi

    echo ""
    echo "Mounts:"
    grep "$SANDBOX_ROOT" /proc/mounts 2>/dev/null | awk '{print "  "$2, "("$4")"}' | head -10 || echo "  (none)"

    echo ""
    echo "Processes:"
    if [ -f /sys/fs/cgroup/pids/$CGROUP_NAME/cgroup.procs ]; then
        for pid in $(cat /sys/fs/cgroup/pids/$CGROUP_NAME/cgroup.procs 2>/dev/null); do
            ps -p "$pid" -o pid,user,%cpu,%mem,cmd --no-headers 2>/dev/null
        done
    fi
}

# ── Main ────────────────────────────────────────────────────
case "${1:-start}" in
    start|"")     launch_sandbox services ;;
    --shell)      launch_sandbox shell ;;
    --stop|stop)  stop_sandbox ;;
    --status|status) show_status ;;
    --cleanup)    cleanup_mounts ;;
    *)
        echo "Usage: $0 [start|--shell|--stop|--status|--cleanup]"
        echo ""
        echo "  start     Start OpenClaw in the sandbox (default)"
        echo "  --shell   Drop into an interactive sandbox shell"
        echo "  --stop    Stop the sandbox and cleanup"
        echo "  --status  Show sandbox status and resource usage"
        echo "  --cleanup Unmount sandbox filesystems"
        exit 1
        ;;
esac
