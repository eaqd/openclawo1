FROM node:24-slim

LABEL maintainer="openclawo1"
LABEL description="OpenClaw AI Assistant with Ollama integration"

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    git \
    curl \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install OpenClaw globally
RUN npm install -g openclaw

# Create non-root user for security
RUN groupadd -r openclaw && useradd -r -g openclaw -m -d /home/openclaw openclaw

# Create directories for config, workspace, and skills
RUN mkdir -p /home/openclaw/.openclaw/skills \
             /home/openclaw/.openclaw/workspace \
    && chown -R openclaw:openclaw /home/openclaw

# Copy default configuration
COPY --chown=openclaw:openclaw config/ /home/openclaw/.openclaw/

# Switch to non-root user
USER openclaw
WORKDIR /home/openclaw

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD openclaw --version || exit 1

ENTRYPOINT ["openclaw"]
