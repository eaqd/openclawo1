#!/bin/bash
# Pull default Ollama model
# This script runs inside the Ollama container after startup.

set -e

MODEL="${OLLAMA_MODEL:-qwen2.5-coder:3b}"
HOST="${OLLAMA_HOST:-http://localhost:11434}"

echo "Waiting for Ollama server..."
until curl -sf "$HOST/api/tags" > /dev/null 2>&1; do
    sleep 2
done

echo "Pulling model: $MODEL"
ollama pull "$MODEL"

echo "Verifying model..."
ollama list | grep -q "$MODEL" && echo "Model $MODEL is ready!" || echo "WARNING: Model verification failed"
