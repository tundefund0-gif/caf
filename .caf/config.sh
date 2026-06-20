#############################################
# CAF Configuration
#############################################

# --- Model Provider ---
# Supported: openrouter, openai, anthropic, ollama
CAF_PROVIDER="${CAF_PROVIDER:-openrouter}"

# --- Model Selection ---
CAF_MODEL="${CAF_MODEL:-openai/gpt-4o-mini:free}"

# --- API Keys (set via env or this file) ---
# OPENROUTER_API_KEY="sk-or-..."
# OPENAI_API_KEY="sk-..."
# ANTHROPIC_API_KEY="sk-ant-..."

# --- API Endpoints ---
CAF_OPENROUTER_URL="https://openrouter.ai/api/v1/chat/completions"
CAF_OPENAI_URL="https://api.openai.com/v1/chat/completions"
CAF_ANTHROPIC_URL="https://api.anthropic.com/v1/messages"
CAF_OLLAMA_URL="http://localhost:11434/api/chat"

# --- Behavior ---
CAF_TEMPERATURE="${CAF_TEMPERATURE:-0.3}"
CAF_MAX_TOKENS="${CAF_MAX_TOKENS:-4096}"
CAF_STREAM="${CAF_STREAM:-true}"              # Enable streaming output
CAF_AUTO_RETRY="${CAF_AUTO_RETRY:-3}"         # Max retries for failed commands
CAF_AUTO_RETRY_DELAY="${CAF_AUTO_RETRY_DELAY:-1}" # Seconds between retries

# --- Memory ---
CAF_MAX_HISTORY="${CAF_MAX_HISTORY:-100}"      # Max messages before compression
CAF_COMPRESSION_THRESHOLD="${CAF_COMPRESSION_THRESHOLD:-50}" # Messages before summarization
CAF_MEMORY_DIR="${CAF_MEMORY_DIR:-$HOME/.caf/memory}"

# --- Project Indexing ---
CAF_INDEX_ENABLED="${CAF_INDEX_ENABLED:-true}"
CAF_INDEX_DIR="${CAF_INDEX_DIR:-$HOME/.caf/index}"
CAF_IGNORE_DIRS="${CAF_IGNORE_DIRS:-.git node_modules target build dist .next .venv .tox __pycache__ .cache}"

# --- Plugins ---
CAF_PLUGIN_DIR="${CAF_PLUGIN_DIR:-$HOME/.caf/plugins}"
CAF_PLUGINS_ENABLED="${CAF_PLUGINS_ENABLED:-true}"

# --- Background Tasks ---
CAF_TASKS_DIR="${CAF_TASKS_DIR:-$HOME/.caf/tasks}"

# --- Web Search ---
CAF_SEARCH_BACKEND="${CAF_SEARCH_BACKEND:-duckduckgo}"  # duckduckgo, searxng, google
CAF_SEARXNG_URL="${CAF_SEARXNG_URL:-http://localhost:8888}"
CAF_MAX_SEARCH_RESULTS="${CAF_MAX_SEARCH_RESULTS:-5}"

# --- Appearance ---
CAF_COLOR="${CAF_COLOR:-true}"
CAF_PROMPT="${CAF_PROMPT:-CAF}"
CAF_LOG_LEVEL="${CAF_LOG_LEVEL:-info}"   # debug, info, warn, error

# --- System ---
CAF_HIST_FILE="$CAF_MEMORY_DIR/history.json"
CAF_SUMMARIES_FILE="$CAF_MEMORY_DIR/summaries.json"
CAF_SESSIONS_DIR="$HOME/.caf/sessions"
CAF_CONFIG_FILE="$HOME/.caf/config.sh"
CAF_AUTO="${CAF_AUTO:-0}"
CAF_TIMEOUT="${CAF_TIMEOUT:-60}"  # Command timeout in seconds
CAF_VERBOSE="${CAF_VERBOSE:-false}"
CAF_AGENTS_DIR="${CAF_AGENTS_DIR:-$HOME/.caf/agents}"
CAF_AGENT_MODE="${CAF_AGENT_MODE:-false}"
CAF_PLUGIN_MANIFEST="${CAF_PLUGIN_MANIFEST:-$HOME/.caf/plugins/registry.json}"
CAF_ENV_FILE="${CAF_ENV_FILE:-$HOME/.caf/.env}"
CAF_USE_TOOLS="${CAF_USE_TOOLS:-true}"
CAF_INIT_TIMESTAMP="${CAF_INIT_TIMESTAMP:-$(date +%s)}"
CAF_RETRY_COUNT="${CAF_RETRY_COUNT:-0}"
CAF_RETRY_MAX="${CAF_RETRY_MAX:-5}"
CAF_TEMP_DIR="${CAF_TEMP_DIR:-/tmp/caf-$$}"
CAF_SELF_HEAL="${CAF_SELF_HEAL:-true}"
CAF_PARALLEL_TOOLS="${CAF_PARALLEL_TOOLS:-false}"
CAF_ERROR_STRATEGY="${CAF_ERROR_STRATEGY:-auto}"  # auto, ask, retry
CAF_DIFF_CONTEXT="${CAF_DIFF_CONTEXT:-10}"
CAF_CACHE_DIR="${CAF_CACHE_DIR:-$HOME/.caf/cache}"
CAF_CACHE_TTL="${CAF_CACHE_TTL:-3600}"
CAF_SAFE_MODE="${CAF_SAFE_MODE:-false}"
CAF_DANGEROUS_COMMANDS="${CAF_DANGEROUS_COMMANDS:-rm dd mkfs format :(){ :|:& };:}"
CAF_CONFIRM_DANGEROUS="${CAF_CONFIRM_DANGEROUS:-true}"

# Source local .env if present
[ -f "$CAF_ENV_FILE" ] && source "$CAF_ENV_FILE"

# --- NVIDIA Provider ---
CAF_NVIDIA_URL="https://integrate.api.nvidia.com/v1/chat/completions"
# NVIDIA_API_KEY="nvapi-..."  (set via env or .env)
