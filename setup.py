#!/usr/bin/env python3
"""
OpenClaw Sandbox Setup Script

First-time setup for OpenClaw with Ollama.
Checks prerequisites, configures environment, pulls models, and starts services.

Usage:
    python3 setup.py
"""

import os
import shutil
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, ".env")
ENV_EXAMPLE = os.path.join(SCRIPT_DIR, ".env.example")

DEFAULT_MODEL = "qwen2.5-coder:3b"


def run(cmd, check=True, capture=False, **kwargs):
    """Run a shell command."""
    kwargs.setdefault("cwd", SCRIPT_DIR)
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
        kwargs["text"] = True
    return subprocess.run(cmd, shell=True, check=check, **kwargs)


def check_prerequisites():
    """Ensure Docker and Docker Compose are installed."""
    print("Checking prerequisites...")

    if not shutil.which("docker"):
        print("ERROR: Docker is not installed.")
        print("Install it from: https://docs.docker.com/get-docker/")
        sys.exit(1)

    # Check Docker Compose (v2 plugin or standalone)
    result = run("docker compose version", check=False, capture=True)
    if result.returncode != 0:
        result = run("docker-compose version", check=False, capture=True)
        if result.returncode != 0:
            print("ERROR: Docker Compose is not installed.")
            print("Install it from: https://docs.docker.com/compose/install/")
            sys.exit(1)

    # Check Docker daemon is running
    result = run("docker info", check=False, capture=True)
    if result.returncode != 0:
        print("ERROR: Docker daemon is not running.")
        print("Start Docker and try again.")
        sys.exit(1)

    print("  Docker .............. OK")
    print("  Docker Compose ...... OK")
    print("  Docker daemon ....... OK")


def configure_env():
    """Create .env file from user input."""
    if os.path.exists(ENV_FILE):
        print(f"\n.env file already exists at {ENV_FILE}")
        response = input("Overwrite? [y/N]: ").strip().lower()
        if response != "y":
            print("Keeping existing .env file.")
            return

    print("\n── Configuration ──────────────────────────────────────")

    # Ollama model
    model = input(f"Ollama model [{DEFAULT_MODEL}]: ").strip()
    if not model:
        model = DEFAULT_MODEL

    # Telegram
    print("\nTelegram bot setup (optional, press Enter to skip):")
    telegram_token = input("  Bot token (from @BotFather): ").strip()
    telegram_users = ""
    if telegram_token:
        telegram_users = input("  Allowed user IDs (comma-separated): ").strip()

    # Log level
    log_level = input(f"Log level [info]: ").strip() or "info"

    # Write .env
    with open(ENV_FILE, "w") as f:
        f.write(f"OLLAMA_MODEL={model}\n")
        f.write(f"TELEGRAM_BOT_TOKEN={telegram_token}\n")
        f.write(f"TELEGRAM_ALLOWED_USERS={telegram_users}\n")
        f.write(f"OPENCLAW_LOG_LEVEL={log_level}\n")

    print(f"\nConfiguration saved to {ENV_FILE}")


def build_and_start():
    """Build images and start containers."""
    print("\n── Building & Starting Services ───────────────────────")

    print("Building OpenClaw image...")
    run("docker compose build --no-cache openclaw")

    print("Starting services...")
    run("docker compose up -d")

    print("Waiting for Ollama to be healthy...")
    for i in range(30):
        result = run(
            "docker compose exec -T ollama curl -sf http://localhost:11434/api/tags",
            check=False, capture=True
        )
        if result.returncode == 0:
            print("  Ollama is ready!")
            break
        time.sleep(2)
    else:
        print("WARNING: Ollama health check timed out. It may still be starting.")


def pull_model():
    """Pull the configured Ollama model."""
    # Read model from .env
    model = DEFAULT_MODEL
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                if line.startswith("OLLAMA_MODEL="):
                    model = line.strip().split("=", 1)[1]
                    break

    print(f"\n── Pulling Model: {model} ─────────────────────────────")
    print("This may take a few minutes on first run...")
    run(f"docker compose exec -T ollama ollama pull {model}")
    print(f"  Model '{model}' is ready!")


def verify():
    """Verify all services are running."""
    print("\n── Verification ──────────────────────────────────────")

    result = run("docker compose ps --format 'table {{.Name}}\t{{.Status}}'",
                 check=False, capture=True)
    if result.returncode == 0:
        print(result.stdout)

    # Check Ollama models
    result = run("docker compose exec -T ollama ollama list",
                 check=False, capture=True)
    if result.returncode == 0:
        print("Installed models:")
        print(result.stdout)


def print_instructions():
    """Print usage instructions."""
    print("""
══════════════════════════════════════════════════════════
  OpenClaw is ready!
══════════════════════════════════════════════════════════

  Usage:
    Interactive shell:  docker compose exec openclaw openclaw
    View logs:          docker compose logs -f openclaw
    Stop all:           docker compose down
    Restart:            docker compose restart

  Management CLI:
    python3 scripts/manage.py status    # Check service health
    python3 scripts/manage.py logs      # Tail logs
    python3 scripts/manage.py models    # List Ollama models
    python3 scripts/manage.py stop      # Stop all services
    python3 scripts/manage.py update    # Update OpenClaw

  Add custom skills:
    Place skill directories in ./skills/
    Each skill needs a SKILL.md file with YAML frontmatter.

  Telegram:
    If configured, message your bot on Telegram to interact.

══════════════════════════════════════════════════════════
""")


def main():
    print("╔══════════════════════════════════════════════════════╗")
    print("║        OpenClaw Sandbox Setup                       ║")
    print("║        Free AI Assistant with Ollama                ║")
    print("╚══════════════════════════════════════════════════════╝\n")

    check_prerequisites()
    configure_env()
    build_and_start()
    pull_model()
    verify()
    print_instructions()


if __name__ == "__main__":
    main()
