#!/usr/bin/env python3
"""
OpenClaw Management CLI

Manage your OpenClaw + Ollama deployment.

Usage:
    python3 scripts/manage.py <command> [args]

Commands:
    start       Start all services
    stop        Stop all services
    restart     Restart all services
    status      Show service status and health
    logs        Tail service logs
    shell       Open a shell in the OpenClaw container
    update      Pull latest images and restart
    models      Manage Ollama models (list/pull/remove)
"""

import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)


def run(cmd, check=True, capture=False, interactive=False):
    """Run a shell command."""
    kwargs = {"cwd": PROJECT_DIR, "shell": True}
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
        kwargs["text"] = True
    if interactive:
        kwargs["stdin"] = sys.stdin
    return subprocess.run(cmd, check=check, **kwargs)


def cmd_start():
    """Start all services."""
    print("Starting OpenClaw services...")
    run("docker compose up -d")
    print("Services started. Use 'status' to check health.")


def cmd_stop():
    """Stop all services."""
    print("Stopping OpenClaw services...")
    run("docker compose down")
    print("All services stopped.")


def cmd_restart():
    """Restart all services."""
    print("Restarting OpenClaw services...")
    run("docker compose restart")
    print("Services restarted.")


def cmd_status():
    """Show service status."""
    print("── Service Status ─────────────────────────────────────")
    run("docker compose ps", check=False)

    print("\n── Ollama Models ──────────────────────────────────────")
    run("docker compose exec -T ollama ollama list", check=False)

    print("\n── Resource Usage ─────────────────────────────────────")
    run("docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' "
        "openclaw-app openclaw-ollama", check=False)


def cmd_logs():
    """Tail service logs."""
    service = ""
    if len(sys.argv) > 2:
        service = sys.argv[2]
    try:
        run(f"docker compose logs -f --tail 100 {service}")
    except KeyboardInterrupt:
        pass


def cmd_shell():
    """Open a shell in the OpenClaw container."""
    print("Opening shell in OpenClaw container...")
    run("docker compose exec openclaw /bin/bash", interactive=True, check=False)


def cmd_update():
    """Update to latest OpenClaw version."""
    print("── Updating OpenClaw ──────────────────────────────────")
    print("Pulling latest base images...")
    run("docker compose pull ollama")
    print("Rebuilding OpenClaw image...")
    run("docker compose build --no-cache openclaw")
    print("Restarting services...")
    run("docker compose up -d")
    print("Update complete!")


def cmd_models():
    """Manage Ollama models."""
    if len(sys.argv) < 3:
        print("Usage: manage.py models <list|pull|remove> [model-name]")
        print("\nExamples:")
        print("  manage.py models list")
        print("  manage.py models pull qwen2.5-coder:7b")
        print("  manage.py models remove phi3:mini")
        print("\nRecommended models for low-end hardware (8GB RAM):")
        print("  qwen2.5-coder:3b    Best for coding (~2.5GB)")
        print("  phi3:mini           General purpose (~2.3GB)")
        print("  llama3.2:3b         General purpose (~2.0GB)")
        print("  deepseek-coder:1.3b Ultra-light coding (~1GB)")
        return

    subcmd = sys.argv[2]

    if subcmd == "list":
        run("docker compose exec -T ollama ollama list", check=False)

    elif subcmd == "pull":
        if len(sys.argv) < 4:
            print("Usage: manage.py models pull <model-name>")
            return
        model = sys.argv[3]
        print(f"Pulling model: {model}...")
        run(f"docker compose exec -T ollama ollama pull {model}")
        print(f"Model '{model}' is ready!")

    elif subcmd == "remove":
        if len(sys.argv) < 4:
            print("Usage: manage.py models remove <model-name>")
            return
        model = sys.argv[3]
        print(f"Removing model: {model}...")
        run(f"docker compose exec -T ollama ollama rm {model}")
        print(f"Model '{model}' removed.")

    else:
        print(f"Unknown models subcommand: {subcmd}")
        print("Use: list, pull, or remove")


COMMANDS = {
    "start": cmd_start,
    "stop": cmd_stop,
    "restart": cmd_restart,
    "status": cmd_status,
    "logs": cmd_logs,
    "shell": cmd_shell,
    "update": cmd_update,
    "models": cmd_models,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        sys.exit(0)

    command = sys.argv[1]
    if command not in COMMANDS:
        print(f"Unknown command: {command}")
        print(f"Available commands: {', '.join(COMMANDS.keys())}")
        sys.exit(1)

    COMMANDS[command]()


if __name__ == "__main__":
    main()
