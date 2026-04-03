#!/usr/bin/env python3
"""
OpenClaw Management CLI

Manage your OpenClaw + Ollama deployment (Docker or direct).

Usage:
    python3 scripts/manage.py <command> [args]

Commands:
    start       Start all services (Ollama + OpenClaw gateway)
    stop        Stop all services
    restart     Restart all services
    status      Show service status and health
    logs        Tail OpenClaw gateway logs
    update      Update OpenClaw to latest version
    models      Manage Ollama models (list/pull/remove)
"""

import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import urllib.request
import json

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

# Valid model name: alphanumeric, dots, colons, hyphens, underscores, slashes
MODEL_NAME_RE = re.compile(r"^[a-zA-Z0-9._:/-]+$")


def validate_model_name(name):
    """Validate model name to prevent injection."""
    if not name or len(name) > 128:
        print(f"ERROR: Invalid model name (empty or too long).")
        sys.exit(1)
    if not MODEL_NAME_RE.match(name):
        print(f"ERROR: Invalid model name '{name}'. Only alphanumeric, dots, colons, hyphens, underscores, and slashes allowed.")
        sys.exit(1)
    return name


def is_docker_mode():
    """Check if Docker daemon is available and compose file exists."""
    compose_file = os.path.join(PROJECT_DIR, "docker-compose.yml")
    if not os.path.exists(compose_file):
        return False
    result = subprocess.run(
        ["docker", "info"], capture_output=True, text=True, cwd=PROJECT_DIR
    )
    return result.returncode == 0


USE_DOCKER = is_docker_mode()


def run(cmd, check=True, capture=False):
    """Run a command (list form, no shell)."""
    env = os.environ.copy()
    env.setdefault("OLLAMA_API_KEY", "ollama-local")
    kwargs = {"cwd": PROJECT_DIR, "env": env}
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
        kwargs["text"] = True
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    return subprocess.run(cmd, check=check, **kwargs)


def run_shell(cmd, check=True, capture=False):
    """Run a shell command (only for simple, trusted commands)."""
    env = os.environ.copy()
    env.setdefault("OLLAMA_API_KEY", "ollama-local")
    kwargs = {"cwd": PROJECT_DIR, "shell": True, "env": env}
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
        kwargs["text"] = True
    return subprocess.run(cmd, check=check, **kwargs)


def ollama_running():
    """Check if Ollama API is reachable."""
    try:
        req = urllib.request.urlopen("http://localhost:11434/api/tags", timeout=3)
        return req.status == 200
    except Exception:
        return False


# ── Commands ─────────────────────────────────────────────


def cmd_start():
    """Start all services."""
    if USE_DOCKER:
        print("Starting Docker services...")
        run(["docker", "compose", "up", "-d"])
    else:
        if not ollama_running():
            print("Starting Ollama server...")
            log_path = os.path.join(PROJECT_DIR, "logs", "ollama.log")
            os.makedirs(os.path.dirname(log_path), exist_ok=True)
            subprocess.Popen(
                ["ollama", "serve"],
                stdout=open(log_path, "a"),
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            import time
            for _ in range(15):
                if ollama_running():
                    break
                time.sleep(1)

        if ollama_running():
            print("  Ollama: running (http://localhost:11434)")
        else:
            print("  Ollama: FAILED to start (check logs/ollama.log)")

        print("Starting OpenClaw gateway...")
        gw_log_path = os.path.join(PROJECT_DIR, "logs", "gateway.log")
        os.makedirs(os.path.dirname(gw_log_path), exist_ok=True)
        subprocess.Popen(
            ["openclaw", "gateway"],
            stdout=open(gw_log_path, "a"),
            stderr=subprocess.STDOUT,
            env={**os.environ, "OLLAMA_API_KEY": "ollama-local"},
            start_new_session=True,
        )
        print("  Gateway: starting (http://localhost:18789)")
        print("\nUse 'status' to verify, 'logs' to follow output.")


def cmd_stop():
    """Stop all services."""
    if USE_DOCKER:
        print("Stopping Docker services...")
        run(["docker", "compose", "down"])
    else:
        print("Stopping OpenClaw gateway...")
        run(["pkill", "-f", "openclaw gateway"], check=False)
        print("Stopping Ollama...")
        run(["pkill", "-f", "ollama serve"], check=False)
    print("All services stopped.")


def cmd_restart():
    """Restart all services."""
    cmd_stop()
    import time
    time.sleep(2)
    cmd_start()


def cmd_status():
    """Show service status."""
    print("-- Service Status -----------------------------------------")

    if USE_DOCKER:
        run(["docker", "compose", "ps"], check=False)
    else:
        if ollama_running():
            print("  Ollama:   RUNNING  (http://localhost:11434)")
        else:
            print("  Ollama:   STOPPED")

        result = run(["pgrep", "-f", "openclaw gateway"], check=False, capture=True)
        if result.returncode == 0:
            print("  Gateway:  RUNNING  (http://localhost:18789)")
        else:
            print("  Gateway:  STOPPED")

    print("\n-- Ollama Models ------------------------------------------")
    if USE_DOCKER:
        run(["docker", "compose", "exec", "-T", "ollama", "ollama", "list"], check=False)
    else:
        run(["ollama", "list"], check=False)

    print("\n-- OpenClaw Models ----------------------------------------")
    run(["openclaw", "models", "list"], check=False)


def cmd_logs():
    """Tail logs."""
    if USE_DOCKER:
        cmd = ["docker", "compose", "logs", "-f", "--tail", "100"]
        if len(sys.argv) > 2:
            cmd.append(sys.argv[2])
        try:
            run(cmd)
        except KeyboardInterrupt:
            pass
    else:
        target = sys.argv[2] if len(sys.argv) > 2 else "openclaw"
        log_dir = os.path.join(PROJECT_DIR, "logs")
        log_file = os.path.join(log_dir, "gateway.log") if target == "openclaw" else os.path.join(log_dir, "ollama.log")
        # Fallback to /tmp if logs dir doesn't exist yet
        if not os.path.exists(log_file):
            log_file = "/tmp/openclaw-gateway.log" if target == "openclaw" else "/tmp/ollama.log"
        print(f"Tailing {log_file} (Ctrl+C to stop)...")
        try:
            run(["tail", "-f", "-n", "100", log_file])
        except KeyboardInterrupt:
            pass


def cmd_update():
    """Update OpenClaw."""
    if USE_DOCKER:
        print("Pulling latest images...")
        run(["docker", "compose", "pull"])
        run(["docker", "compose", "up", "-d"])
    else:
        print("Updating OpenClaw...")
        run(["npm", "update", "-g", "openclaw"])
        print("Updated to: ", end="")
        run(["openclaw", "--version"])


def cmd_models():
    """Manage Ollama models."""
    if len(sys.argv) < 3:
        print("Usage: manage.py models <list|pull|remove> [model-name]")
        print("\nExamples:")
        print("  manage.py models list")
        print("  manage.py models pull qwen3.5:4b")
        print("  manage.py models remove phi3:mini")
        print("\nRecommended models (Qwen 3.5):")
        print("  qwen3.5:4b          Best balance for 8GB (~4GB)")
        print("  qwen3.5:2b          Lighter (~3GB)")
        print("  qwen3.5:0.8b        Ultra-light (~2GB)")
        print("  qwen3.5:9b          Best quality, 16GB+ (~8GB)")
        return

    subcmd = sys.argv[2]

    if USE_DOCKER:
        ollama_base = ["docker", "compose", "exec", "-T", "ollama", "ollama"]
    else:
        ollama_base = ["ollama"]

    if subcmd == "list":
        run(ollama_base + ["list"], check=False)
    elif subcmd == "pull":
        if len(sys.argv) < 4:
            print("Usage: manage.py models pull <model-name>")
            return
        model = validate_model_name(sys.argv[3])
        print(f"Pulling model: {model}...")
        run(ollama_base + ["pull", model])
        print(f"Model '{model}' is ready!")
    elif subcmd == "remove":
        if len(sys.argv) < 4:
            print("Usage: manage.py models remove <model-name>")
            return
        model = validate_model_name(sys.argv[3])
        print(f"Removing model: {model}...")
        run(ollama_base + ["rm", model])
        print(f"Model '{model}' removed.")
    else:
        print(f"Unknown subcommand: {subcmd}. Use: list, pull, or remove")


COMMANDS = {
    "start": cmd_start,
    "stop": cmd_stop,
    "restart": cmd_restart,
    "status": cmd_status,
    "logs": cmd_logs,
    "update": cmd_update,
    "models": cmd_models,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        mode = "Docker" if USE_DOCKER else "Direct (bare-metal)"
        print(f"  Detected mode: {mode}")
        sys.exit(0)

    command = sys.argv[1]
    if command not in COMMANDS:
        print(f"Unknown command: {command}")
        print(f"Available: {', '.join(COMMANDS.keys())}")
        sys.exit(1)

    COMMANDS[command]()


if __name__ == "__main__":
    main()
