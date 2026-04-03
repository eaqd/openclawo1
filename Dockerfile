# Custom OpenClaw image (alternative to the official ghcr.io/openclaw/openclaw)
# Use this if you need to build from source or customize the installation.
# By default, docker-compose.yml uses the official image instead.
#
# To use this Dockerfile, change docker-compose.yml openclaw service to:
#   build:
#     context: .
#     dockerfile: Dockerfile

FROM node:24-slim

LABEL maintainer="openclawo1"
LABEL description="OpenClaw AI Assistant with Ollama integration"

ENV DEBIAN_FRONTEND=noninteractive

# Install only required system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw && npm cache clean --force

# Create non-root user
RUN groupadd -r openclaw && useradd -r -g openclaw -m -d /home/node -s /bin/false openclaw

# Create directories
RUN mkdir -p /home/node/.openclaw/skills \
             /home/node/.openclaw/workspace \
    && chown -R openclaw:openclaw /home/node

USER openclaw
WORKDIR /home/node

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD openclaw --version || exit 1

ENTRYPOINT ["openclaw"]
