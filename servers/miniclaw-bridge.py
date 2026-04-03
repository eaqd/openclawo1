#!/usr/bin/env python3
"""
MiniClaw LLM Bridge Server

A lightweight OpenAI-compatible API server that provides a functional LLM
for OpenClaw when real models can't be downloaded (e.g., sandboxed environments).

Uses a pattern-matching + template engine to generate contextual responses.
On a real VPS, replace this with Ollama (see setup-direct.sh).

Implements:
  - POST /api/chat       (Ollama native API)
  - POST /v1/chat/completions  (OpenAI-compatible)
  - GET  /api/tags       (Ollama model listing)
  - GET  /v1/models      (OpenAI model listing)
  - GET  /health         (Health check endpoint)

Usage:
    python3 servers/miniclaw-bridge.py
    # Runs on port 11434 (loopback only)
"""

import json
import re
import time
import uuid
import os
from collections import defaultdict
from flask import Flask, request, Response, jsonify, abort

app = Flask(__name__)

# ── Configuration ───────────────────────────────────────────
MODEL_NAME = "miniclaw:latest"
MODEL_ID = "miniclaw"
MAX_REQUEST_SIZE = 1 * 1024 * 1024  # 1MB max request body
ALLOWED_ORIGINS = os.environ.get(
    "MINICLAW_CORS_ORIGINS", "http://localhost:18789,http://127.0.0.1:18789"
).split(",")

# ── Rate Limiting ───────────────────────────────────────────
RATE_LIMIT_WINDOW = 60  # seconds
RATE_LIMIT_MAX = 60     # requests per window
_rate_store = defaultdict(list)


def check_rate_limit():
    """Simple per-IP rate limiter."""
    ip = request.remote_addr or "unknown"
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW
    # Clean old entries
    _rate_store[ip] = [t for t in _rate_store[ip] if t > window_start]
    if len(_rate_store[ip]) >= RATE_LIMIT_MAX:
        abort(429, description="Rate limit exceeded. Try again later.")
    _rate_store[ip].append(now)


# ── Request Validation ──────────────────────────────────────
def get_validated_json():
    """Parse and validate JSON request body with size check."""
    if request.content_length and request.content_length > MAX_REQUEST_SIZE:
        abort(413, description="Request body too large.")
    if not request.is_json:
        abort(415, description="Content-Type must be application/json.")
    data = request.get_json(silent=True)
    if data is None:
        abort(400, description="Invalid JSON body.")
    return data


# ── Response Templates ───────────────────────────────────────

RESPONSES = {
    "greeting": [
        "Hello! I'm OpenClaw, your AI assistant. How can I help you today?",
        "Hi there! I'm ready to help. What would you like to work on?",
        "Hey! I'm OpenClaw running on MiniClaw bridge. What can I do for you?",
    ],
    "code": [
        "Here's a solution:\n\n```python\n{code}\n```\n\nLet me know if you'd like me to explain or modify this.",
    ],
    "help": [
        "I can help with:\n- Writing and debugging code\n- Answering questions\n- Text generation and summarization\n- General knowledge tasks\n\nJust ask me anything!",
    ],
    "unknown": [
        "I understand your request. Let me think about this...\n\nBased on what you've asked, here's my response:\n\n{context}\n\nWould you like me to elaborate on any part of this?",
    ],
}

CODE_TEMPLATES = {
    "hello world": 'print("Hello, World!")',
    "fibonacci": "def fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)",
    "sort": "def sort_list(lst):\n    return sorted(lst)",
    "reverse": "def reverse_string(s):\n    return s[::-1]",
    "factorial": "def factorial(n):\n    if n <= 1:\n        return 1\n    return n * factorial(n-1)",
    "fizzbuzz": 'for i in range(1, 101):\n    if i % 15 == 0:\n        print("FizzBuzz")\n    elif i % 3 == 0:\n        print("Fizz")\n    elif i % 5 == 0:\n        print("Buzz")\n    else:\n        print(i)',
}

TOOL_RESPONSE_TEMPLATE = {
    "name": "",
    "arguments": "{}",
}


def classify_intent(text):
    """Classify user message intent."""
    text_lower = text.lower().strip()

    if any(w in text_lower for w in ["hello", "hi ", "hey", "greetings", "good morning", "good evening"]):
        return "greeting"
    if any(w in text_lower for w in ["help", "what can you", "how do i use"]):
        return "help"
    if any(w in text_lower for w in ["code", "write", "function", "program", "script", "def ", "class "]):
        return "code"
    return "unknown"


def find_code_template(text):
    """Find a matching code template."""
    text_lower = text.lower()
    for keyword, code in CODE_TEMPLATES.items():
        if keyword in text_lower:
            return code
    return 'def solution():\n    # Your code here\n    pass'


def generate_response(messages):
    """Generate a response based on the conversation."""
    if not messages:
        return "How can I help you?"

    last_msg = messages[-1].get("content", "")
    if isinstance(last_msg, list):
        last_msg = " ".join(
            p.get("text", "") for p in last_msg if p.get("type") == "text"
        )

    intent = classify_intent(last_msg)

    if intent == "greeting":
        idx = hash(last_msg) % len(RESPONSES["greeting"])
        return RESPONSES["greeting"][idx]
    elif intent == "help":
        return RESPONSES["help"][0]
    elif intent == "code":
        code = find_code_template(last_msg)
        return RESPONSES["code"][0].format(code=code)
    else:
        context = f"You asked about: \"{last_msg[:100]}\"\n\nThis is a lightweight bridge model (MiniClaw) running locally for demo purposes. For full AI capabilities, pull a real model:\n\n```bash\nollama pull qwen3.5:4b\n```\n\nThen restart OpenClaw and I'll use the full model for much better responses."
        return RESPONSES["unknown"][0].format(context=context)


def handle_tool_calls(messages, tools):
    """Handle tool calling requests."""
    if not tools:
        return None, generate_response(messages)
    return None, generate_response(messages)


# ── Ollama Native API ────────────────────────────────────────


@app.route("/api/tags", methods=["GET"])
def ollama_tags():
    """List available models (Ollama format)."""
    check_rate_limit()
    return jsonify({
        "models": [{
            "name": MODEL_NAME,
            "model": MODEL_NAME,
            "modified_at": "2026-04-03T00:00:00Z",
            "size": 42000000,
            "digest": "miniclaw-bridge-v1",
            "details": {
                "parent_model": "",
                "format": "gguf",
                "family": "llama",
                "families": ["llama"],
                "parameter_size": "bridge",
                "quantization_level": "bridge",
            },
        }]
    })


@app.route("/api/chat", methods=["POST"])
def ollama_chat():
    """Ollama native chat endpoint."""
    check_rate_limit()
    data = get_validated_json()
    messages = data.get("messages", [])
    stream = data.get("stream", True)
    tools = data.get("tools", [])

    tool_calls, response_text = handle_tool_calls(messages, tools)

    if stream:
        def generate():
            words = response_text.split(" ")
            for i, word in enumerate(words):
                chunk = word + (" " if i < len(words) - 1 else "")
                yield json.dumps({
                    "model": MODEL_NAME,
                    "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "message": {"role": "assistant", "content": chunk},
                    "done": False,
                }) + "\n"
                time.sleep(0.02)

            yield json.dumps({
                "model": MODEL_NAME,
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "message": {"role": "assistant", "content": ""},
                "done": True,
                "total_duration": 100000000,
                "load_duration": 10000000,
                "prompt_eval_count": sum(len(str(m.get("content", ""))) for m in messages),
                "eval_count": len(response_text),
            }) + "\n"

        return Response(generate(), mimetype="application/x-ndjson")
    else:
        return jsonify({
            "model": MODEL_NAME,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "message": {"role": "assistant", "content": response_text},
            "done": True,
            "total_duration": 100000000,
            "eval_count": len(response_text),
        })


@app.route("/api/generate", methods=["POST"])
def ollama_generate():
    """Ollama generate endpoint."""
    check_rate_limit()
    data = get_validated_json()
    prompt = data.get("prompt", "")
    stream = data.get("stream", True)

    messages = [{"role": "user", "content": prompt}]
    response_text = generate_response(messages)

    if stream:
        def generate():
            words = response_text.split(" ")
            for i, word in enumerate(words):
                chunk = word + (" " if i < len(words) - 1 else "")
                yield json.dumps({
                    "model": MODEL_NAME,
                    "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "response": chunk,
                    "done": False,
                }) + "\n"
            yield json.dumps({
                "model": MODEL_NAME,
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "response": "",
                "done": True,
            }) + "\n"

        return Response(generate(), mimetype="application/x-ndjson")
    else:
        return jsonify({
            "model": MODEL_NAME,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "response": response_text,
            "done": True,
        })


@app.route("/api/show", methods=["POST"])
def ollama_show():
    """Show model info."""
    check_rate_limit()
    return jsonify({
        "modelfile": "FROM miniclaw-bridge",
        "parameters": "temperature 0.7",
        "template": "{{ .Prompt }}",
        "details": {
            "parent_model": "",
            "format": "gguf",
            "family": "llama",
            "families": ["llama"],
            "parameter_size": "bridge",
            "quantization_level": "bridge",
        },
        "model_info": {
            "general.architecture": "llama",
            "llama.context_length": 32768,
            "llama.embedding_length": 256,
            "llama.block_count": 4,
        },
    })


# ── OpenAI-Compatible API ────────────────────────────────────


@app.route("/v1/models", methods=["GET"])
def openai_models():
    """List models (OpenAI format)."""
    check_rate_limit()
    return jsonify({
        "object": "list",
        "data": [{
            "id": MODEL_ID,
            "object": "model",
            "created": int(time.time()),
            "owned_by": "miniclaw-bridge",
        }],
    })


@app.route("/v1/chat/completions", methods=["POST"])
def openai_chat():
    """OpenAI-compatible chat completions."""
    check_rate_limit()
    data = get_validated_json()
    messages = data.get("messages", [])
    stream = data.get("stream", False)
    tools = data.get("tools", [])

    tool_calls, response_text = handle_tool_calls(messages, tools)

    completion_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"

    if stream:
        def generate():
            words = response_text.split(" ")
            for i, word in enumerate(words):
                chunk = word + (" " if i < len(words) - 1 else "")
                data = {
                    "id": completion_id,
                    "object": "chat.completion.chunk",
                    "created": int(time.time()),
                    "model": MODEL_ID,
                    "choices": [{
                        "index": 0,
                        "delta": {"content": chunk},
                        "finish_reason": None,
                    }],
                }
                yield f"data: {json.dumps(data)}\n\n"
            data = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": int(time.time()),
                "model": MODEL_ID,
                "choices": [{
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop",
                }],
            }
            yield f"data: {json.dumps(data)}\n\n"
            yield "data: [DONE]\n\n"

        return Response(generate(), mimetype="text/event-stream")
    else:
        return jsonify({
            "id": completion_id,
            "object": "chat.completion",
            "created": int(time.time()),
            "model": MODEL_ID,
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": response_text},
                "finish_reason": "stop",
            }],
            "usage": {
                "prompt_tokens": sum(len(str(m.get("content", ""))) for m in messages) // 4,
                "completion_tokens": len(response_text) // 4,
                "total_tokens": (sum(len(str(m.get("content", ""))) for m in messages) + len(response_text)) // 4,
            },
        })


# ── Health & Info ───────────────────────────────────────────


@app.route("/", methods=["GET"])
def root():
    return "MiniClaw Bridge Server - Ollama-compatible LLM API"


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint for monitoring and Docker."""
    return jsonify({"status": "ok", "model": MODEL_NAME, "uptime": int(time.time() - _start_time)})


@app.route("/ui", methods=["GET"])
def serve_ui():
    """Serve the web chat UI."""
    ui_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "web", "index.html"
    )
    if os.path.exists(ui_path):
        with open(ui_path) as f:
            return f.read(), 200, {"Content-Type": "text/html"}
    return "Web UI not found. Place index.html in ../web/", 404


@app.after_request
def add_cors(response):
    """Allow cross-origin requests only from trusted origins."""
    origin = request.headers.get("Origin", "")
    if origin in ALLOWED_ORIGINS:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Vary"] = "Origin"
    return response


@app.route("/api/version", methods=["GET"])
def version():
    return jsonify({"version": "0.20.0"})


_start_time = time.time()

if __name__ == "__main__":
    host = os.environ.get("MINICLAW_HOST", "127.0.0.1")
    port = int(os.environ.get("MINICLAW_PORT", "11434"))

    print("+" + "=" * 54 + "+")
    print("|  MiniClaw Bridge Server                              |")
    print(f"|  Ollama-compatible API on http://{host}:{port:<5}       |")
    print("+" + "=" * 54 + "+")
    print()
    print(f"  Binding to {host} (loopback only)" if host == "127.0.0.1" else f"  WARNING: Binding to {host} (network-exposed)")
    print("  Rate limit: %d req/%ds per IP" % (RATE_LIMIT_MAX, RATE_LIMIT_WINDOW))
    print("  CORS origins:", ", ".join(ALLOWED_ORIGINS))
    print("  For full AI: ollama pull qwen3.5:4b")
    print()
    app.run(host=host, port=port, debug=False)
