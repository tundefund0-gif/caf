#!/usr/bin/env bash

#############################################
# CAF v2.0 - Advanced Terminal Coding Agent
# Self-healing, streaming, plugin-powered
#############################################

set -o pipefail

# --- Bootstrap: minimal config loading ---
# Look for .caf/ next to the script first, then fall back to ~/.caf
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)"
if [ -d "$SCRIPT_DIR/.caf" ] && [ "$SCRIPT_DIR/.caf" != "$HOME/.caf" ]; then
  CAF_HOME="${CAF_HOME:-$SCRIPT_DIR/.caf}"
else
  CAF_HOME="${CAF_HOME:-$HOME/.caf}"
fi
CAF_CONFIG_FILE="${CAF_CONFIG_FILE:-$CAF_HOME/config.sh}"
mkdir -p "$CAF_HOME"/{plugins,memory,sessions,index,tasks,cache} 2>/dev/null

# Save user-set model before config overrides it
CAF_USER_MODEL="${CAF_MODEL:-}"
# Source config
[ -f "$CAF_CONFIG_FILE" ] && source "$CAF_CONFIG_FILE"

# Defaults if not set by config
CAF_TEMP_DIR="${CAF_TEMP_DIR:-${TMPDIR:-/tmp}/caf-$$}"
mkdir -p "$CAF_TEMP_DIR" 2>/dev/null
CAF_MEMORY_DIR="${CAF_MEMORY_DIR:-$CAF_HOME/memory}"
CAF_PLUGIN_DIR="${CAF_PLUGIN_DIR:-$CAF_HOME/plugins}"
CAF_TASKS_DIR="${CAF_TASKS_DIR:-$CAF_HOME/tasks}"
CAF_INDEX_DIR="${CAF_INDEX_DIR:-$CAF_HOME/index}"
CAF_SESSIONS_DIR="${CAF_SESSIONS_DIR:-$CAF_HOME/sessions}"
CAF_HIST_FILE="${CAF_HIST_FILE:-$CAF_MEMORY_DIR/history.json}"
CAF_SUMMARIES_FILE="${CAF_SUMMARIES_FILE:-$CAF_MEMORY_DIR/summaries.json}"
CAF_CACHE_DIR="${CAF_CACHE_DIR:-$CAF_HOME/cache}"
CAF_PLUGIN_REGISTRY="${CAF_PLUGIN_REGISTRY:-$CAF_PLUGIN_DIR/registry.json}"
CAF_ENV_FILE="${CAF_ENV_FILE:-$CAF_HOME/.env}"
CAF_STREAM="${CAF_STREAM:-true}"
CAF_AUTO_RETRY="${CAF_AUTO_RETRY:-3}"
CAF_AUTO_RETRY_DELAY="${CAF_AUTO_RETRY_DELAY:-1}"
CAF_MAX_HISTORY="${CAF_MAX_HISTORY:-100}"
CAF_COMPRESSION_THRESHOLD="${CAF_COMPRESSION_THRESHOLD:-50}"
CAF_TEMPERATURE="${CAF_TEMPERATURE:-0.3}"
CAF_MAX_TOKENS="${CAF_MAX_TOKENS:-4096}"
CAF_TIMEOUT="${CAF_TIMEOUT:-60}"
CAF_COLOR="${CAF_COLOR:-true}"
CAF_VERBOSE="${CAF_VERBOSE:-false}"
CAF_AUTO="${CAF_AUTO:-0}"
CAF_LOG_LEVEL="${CAF_LOG_LEVEL:-info}"
CAF_USE_TOOLS="${CAF_USE_TOOLS:-true}"
CAF_PROVIDER="${CAF_PROVIDER:-openrouter}"
CAF_MODEL="${CAF_MODEL:-openai/gpt-4o-mini:free}"
CAF_SELF_HEAL="${CAF_SELF_HEAL:-true}"
CAF_CONFIRM_DANGEROUS="${CAF_CONFIRM_DANGEROUS:-true}"
CAF_DANGEROUS_COMMANDS="${CAF_DANGEROUS_COMMANDS:-rm dd mkfs format}"
CAF_PROMPT="${CAF_PROMPT:-CAF}"

mkdir -p "$CAF_TEMP_DIR" "$CAF_MEMORY_DIR" "$CAF_TASKS_DIR" 2>/dev/null

# --- Color Support ---
if [ "$CAF_COLOR" = "true" ] && [ -t 1 ]; then
  C_RED='\033[0;31m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[1;33m'
  C_BLUE='\033[0;34m'
  C_MAGENTA='\033[0;35m'
  C_CYAN='\033[0;36m'
  C_WHITE='\033[1;37m'
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_DIM='\033[2m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
  C_MAGENTA=''; C_CYAN=''; C_WHITE=''; C_RESET=''
  C_BOLD=''; C_DIM=''
fi

# ============================================
# LOGGING SYSTEM
# ============================================
_log_debug() { [ "$CAF_LOG_LEVEL" = "debug" ] && echo -e "${C_DIM}[DEBUG]${C_RESET} $*" >&2; }
_log_info()  { echo -e "${C_GREEN}[INFO]${C_RESET} $*" >&2; }
_log_warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $*" >&2; }
_log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $*" >&2; }

log_debug() { _log_debug "$@"; }
log_info()  { _log_info "$@"; }
log_warn()  { _log_warn "$@"; }
log_error() { _log_error "$@"; }

# ============================================
# DEPENDENCY CHECK
# ============================================
# Auto-detect provider from available API keys if not explicitly set
if [ "${CAF_PROVIDER:-}" = "openrouter" ] && [ -z "${OPENROUTER_API_KEY:-}" ]; then
  if [ -n "${NVIDIA_API_KEY:-}" ]; then
    CAF_PROVIDER="nvidia"
    [ -z "$CAF_USER_MODEL" ] && CAF_MODEL="nvidia/nemotron-3-super-120b-a12b"
    log_info "Auto-detected NVIDIA provider from NVIDIA_API_KEY"
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    CAF_PROVIDER="openai"
    [ -z "$CAF_USER_MODEL" ] && CAF_MODEL="gpt-4o"
    log_info "Auto-detected OpenAI provider from OPENAI_API_KEY"
  elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    [ -z "$CAF_USER_MODEL" ] && CAF_MODEL="claude-3-5-sonnet-20241022"
    CAF_PROVIDER="anthropic"
    log_info "Auto-detected Anthropic provider from ANTHROPIC_API_KEY"
  fi
fi
_init_deps() {
  local missing=0

  command -v curl &>/dev/null || { log_error "curl required"; missing=1; }
  command -v jq &>/dev/null   || { log_error "jq required";   missing=1; }

  # Provider-specific checks
  case "$CAF_PROVIDER" in
    openrouter)
      [ -z "$OPENROUTER_API_KEY" ] && {
        log_error "OPENROUTER_API_KEY not set. Set it or use a different provider (e.g., CAF_PROVIDER=nvidia with NVIDIA_API_KEY)"
        missing=1
      }
      ;;
    openai)
      [ -z "$OPENAI_API_KEY" ] && {
        log_error "OPENAI_API_KEY not set. Set it or use a different provider (e.g., CAF_PROVIDER=nvidia with NVIDIA_API_KEY)"
        missing=1
      }
      ;;
    anthropic)
      [ -z "$ANTHROPIC_API_KEY" ] && {
        log_error "ANTHROPIC_API_KEY not set. Set it or use a different provider (e.g., CAF_PROVIDER=nvidia with NVIDIA_API_KEY)"
        missing=1
      }
      ;;
    ollama)
      log_info "Using local Ollama - no API key needed"
      ;;
    nvidia)
      [ -z "$NVIDIA_API_KEY" ] && {
        log_error "NVIDIA_API_KEY not set. Set NVIDIA_API_KEY or use a different provider (e.g., CAF_PROVIDER=openrouter with OPENROUTER_API_KEY)"
        missing=1
      }
      ;;
  esac

  [ "$missing" -eq 1 ] && exit 1
  return 0
}

# ============================================
# MEMORY / HISTORY SYSTEM
# ============================================

# Load history from file
_memory_load() {
  if [ -f "$CAF_HIST_FILE" ]; then
    HISTORY=$(cat "$CAF_HIST_FILE" 2>/dev/null)
    _log_debug "Loaded history ($(echo "$HISTORY" | jq length) messages)"
  else
    HISTORY="[]"
    _log_debug "No history file, starting fresh"
  fi
}

# Save history to file
_memory_save() {
  echo "$HISTORY" > "$CAF_HIST_FILE" 2>/dev/null
  _log_debug "Saved history ($(echo "$HISTORY" | jq length) messages)"
}

# Add a message to history
_memory_add() {
  local role="$1"
  local content="$2"

  # Escape content for JSON
  local escaped
  escaped=$(printf '%s' "$content" | jq -R -s '.')
  HISTORY=$(echo "$HISTORY" | jq \
    --arg r "$role" \
    --argjson c "$escaped" \
    '. + [{"role":$r,"content":$c}]')

  _memory_save

  # Check if compression needed
  _memory_compress_if_needed
}

# Compress/summarize old messages to save context window
_memory_compress_if_needed() {
  local count
  count=$(echo "$HISTORY" | jq length)

  if [ "$count" -le "$CAF_COMPRESSION_THRESHOLD" ]; then
    return 0
  fi

  _log_info "Compressing memory ($count messages, threshold $CAF_COMPRESSION_THRESHOLD)"

  # Take the first N-20 messages and compress them into a summary
  local keep=20
  local compress_end=$((count - keep))
  local compress_count=$((compress_end))

  if [ "$compress_count" -lt 5 ]; then
    return 0  # Not enough to compress
  fi

  # Extract the messages to compress
  local to_compress
  to_compress=$(echo "$HISTORY" | jq ".[0:$compress_end]")

  # Extract the messages to keep
  local to_keep
  to_keep=$(echo "$HISTORY" | jq ".[-$keep:]")

  # Build a simple summary by extracting key info
  local summary_text
  summary_text=$(
    echo "$to_compress" | jq -r '
      group_by(.role) | map({
        role: .[0].role,
        count: length,
        topics: [.[].content | split("\n")[:3][] | select(length > 20)] | unique[:5]
      }) | .[] | "Role: \(.role) - \(.count) messages\nKey topics:\n\(.topics | map("  - \(.[:120])") | join("\n"))"
    '
  )

  local summary_msg="[MEMORY COMPRESSION - Previous conversation summarized]
Previously exchanged messages: $compress_count messages
Summary:
$summary_text"

  # Rebuild history: system messages + summary + recent messages
  local system_msgs
  system_msgs=$(echo "$HISTORY" | jq '[.[] | select(.role == "system")]')

  # Get the first system message (the main system prompt)
  local system_prompt
  system_prompt=$(echo "$system_msgs" | jq '.[0]')

  # Rebuild
  HISTORY=$(echo '[]' | jq \
    --argjson sys "$system_prompt" \
    --arg summary "$summary_msg" \
    --argjson recent "$to_keep" \
    '. + [$sys] + [{"role":"system","content":$summary}] + $recent')

  _memory_save
  _log_info "Memory compressed: $compress_count messages summarized"
}

# Clear history
_memory_clear() {
  HISTORY="[]"
  _memory_save
  _log_info "History cleared"
}

# Save a session snapshot
_memory_save_session() {
  local name="${1:-session-$(date +%Y%m%d-%H%M%S)}"
  cp "$CAF_HIST_FILE" "$CAF_SESSIONS_DIR/${name}.json" 2>/dev/null
  _log_info "Session saved: $name"
}

# Load a session
_memory_load_session() {
  local name="$1"
  local sess_file="$CAF_SESSIONS_DIR/${name}.json"
  if [ -f "$sess_file" ]; then
    HISTORY=$(cat "$sess_file")
    _memory_save
    _log_info "Session loaded: $name"
    return 0
  else
    _log_error "Session not found: $name"
    return 1
  fi
}

# List sessions
_memory_list_sessions() {
  echo "**Saved Sessions**"
  for f in "$CAF_SESSIONS_DIR"/*.json; do
    [ -f "$f" ] || continue
    local name
    name=$(basename "$f" .json)
    local count
    count=$(cat "$f" | jq length 2>/dev/null)
    echo "  $name ($count messages)"
  done
}

# ============================================
# PLUGIN SYSTEM
# ============================================

declare -A TOOL_REGISTRY
declare -A PLUGIN_REGISTRY

# Register a tool handler
register_tool() {
  local name="$1"
  local handler="$2"
  TOOL_REGISTRY["$name"]="$handler"
  _log_debug "Registered tool: $name -> $handler"
}

# Load all plugins
_plugins_load() {
  [ "$CAF_PLUGINS_ENABLED" = "false" ] && { _log_info "Plugins disabled"; return 0; }

  local plugin_dir="$CAF_PLUGIN_DIR"
  local count=0
  local loaded_any=false

  # Try configured plugin directory first
  if [ -d "$plugin_dir" ]; then
    for f in "$plugin_dir"/*.sh; do
      [ -f "$f" ] || continue
      _log_info "Loading plugin: $(basename "$f")"
      source "$f" 2>/dev/null && count=$((count + 1)) || _log_warn "Failed to load plugin: $f"
    done
    [ "$count" -gt 0 ] && loaded_any=true
  fi

  # Fallback: try .caf/ next to the script
  if ! $loaded_any; then
    local script_caf
    script_caf="$(cd "$(dirname "$0")" && pwd 2>/dev/null)/.caf/plugins"
    if [ -d "$script_caf" ] && [ "$script_caf" != "$plugin_dir" ]; then
      _log_info "Looking for plugins in: $script_caf"
      for f in "$script_caf"/*.sh; do
        [ -f "$f" ] || continue
        _log_info "Loading plugin: $(basename "$f")"
        source "$f" 2>/dev/null && count=$((count + 1)) || _log_warn "Failed to load plugin: $f"
      done
      [ "$count" -gt 0 ] && loaded_any=true
    fi
  fi

  # Fallback: try $HOME/.caf/plugins
  if ! $loaded_any; then
    local home_caf="$HOME/.caf/plugins"
    if [ -d "$home_caf" ] && [ "$home_caf" != "$plugin_dir" ]; then
      _log_info "Looking for plugins in: $home_caf"
      for f in "$home_caf"/*.sh; do
        [ -f "$f" ] || continue
        _log_info "Loading plugin: $(basename "$f")"
        source "$f" 2>/dev/null && count=$((count + 1)) || _log_warn "Failed to load plugin: $f"
      done
    fi
  fi

  if ! $loaded_any; then
    _log_debug "No plugins found in configured or fallback directories"
  fi

  _log_info "Loaded $count plugin(s)"
  _log_debug "Tools available: ${!TOOL_REGISTRY[*]}"
  return 0
}
_tool_dispatch() {
  local tool_name="$1"
  local json_data="$2"

  local handler="${TOOL_REGISTRY[$tool_name]}"

  if [ -n "$handler" ]; then
    _log_debug "Dispatching tool: $tool_name (handler: $handler)"

    # Extract arguments from JSON
    local data
    local data="$json_data"

    # Call the handler
    if declare -F "$handler" &>/dev/null; then
      "$handler" "$data" 2>&1
      local rc=$?
      _log_debug "Tool $tool_name completed (exit: $rc)"
      return $rc
    else
      _log_error "Handler $handler not found for tool $tool_name"
      return 1
    fi
  else
    _log_error "Unknown tool: $tool_name"
    return 1
  fi
}

# ============================================
# BUILT-IN TOOLS
# ============================================

_tool_run() {
  local data="$1"
  local cmd
  cmd=$(echo "$data" | jq -r '.command // empty')
  local description
  description=$(echo "$data" | jq -r '.description // .command // empty')
  local timeout
  timeout=$(echo "$data" | jq -r '.timeout // '"$CAF_TIMEOUT"'')
  local retry_strategy
  retry_strategy=$(echo "$data" | jq -r '.retry // "auto"')

  [ -z "$cmd" ] && { echo '{"error":"No command specified"}'; return 1; }

  _log_info "Running: $description"
  _log_debug "Command: $cmd"

  # Check for dangerous commands
  if [ "$CAF_CONFIRM_DANGEROUS" = "true" ]; then
    for d_cmd in $CAF_DANGEROUS_COMMANDS; do
      if echo "$cmd" | grep -qw "$d_cmd"; then
        _log_warn "DANGEROUS COMMAND DETECTED: $cmd"
        echo "⚠️  This command contains dangerous operations."
        echo "Command: $cmd"
        echo -n "Execute anyway? (yes/no): "
        read -r confirm
        [ "$confirm" != "yes" ] && { echo "Cancelled."; return 1; }
        break
      fi
    done
  fi

  local max_retries="$CAF_AUTO_RETRY"
  [ "$retry_strategy" = "none" ] && max_retries=0

  local attempt=1
  local cmd_output=""
  local rc=0

  while [ "$attempt" -le "$((max_retries + 1))" ]; do
    if [ "$attempt" -gt 1 ]; then
      _log_info "Retry #$((attempt - 1))..."
      sleep "$CAF_AUTO_RETRY_DELAY"
    fi

    # Execute with timeout
    if command -v timeout &>/dev/null; then
      cmd_output=$(timeout "$timeout" bash -c "$cmd" 2>&1)
      rc=$?
    else
      cmd_output=$(bash -c "$cmd" 2>&1)
      rc=$?
    fi

    # Success?
    if [ "$rc" -eq 0 ]; then
      echo "$cmd_output"
      _log_info "Command succeeded (attempt $attempt)"
      return 0
    fi

    _log_warn "Command failed (attempt $attempt, exit: $rc)"

    # Self-healing: try to fix common issues
    if [ "$CAF_SELF_HEAL" = "true" ] && [ "$attempt" -le "$max_retries" ]; then
      local fixed_cmd
      fixed_cmd=$(_self_heal_attempt "$cmd" "$cmd_output")
      if [ -n "$fixed_cmd" ] && [ "$fixed_cmd" != "$cmd" ]; then
        _log_info "Self-heal: modified command -> $fixed_cmd"
        cmd="$fixed_cmd"
      fi
    fi

    attempt=$((attempt + 1))
  done

  # All retries failed
  echo "$cmd_output"
  _log_error "Command failed after $attempt attempts"
  return $rc
}

# Self-healing logic - try to fix common command errors
_self_heal_attempt() {
  local cmd="$1"
  local output="$2"

  # If command not found, try installing
  if echo "$output" | grep -qi "command not found"; then
    local missing_cmd
    missing_cmd=$(echo "$output" | grep -oP ".*?:\s+\K\S+" | head -1)
    if [ -n "$missing_cmd" ]; then
      _log_info "Self-heal: attempting to install '$missing_cmd'"
      if command -v pkg &>/dev/null; then
        pkg install -y "$missing_cmd" 2>/dev/null && echo "$cmd" && return 0
      elif command -v apt-get &>/dev/null; then
        apt-get install -y "$missing_cmd" 2>/dev/null && echo "$cmd" && return 0
      fi
    fi
  fi

  # If permission denied, add execute permission
  if echo "$output" | grep -qi "permission denied"; then
    local target
    target=$(echo "$cmd" | grep -oP '(?:\./)?\S+' | head -1)
    [ -f "$target" ] && chmod +x "$target" 2>/dev/null && echo "$cmd" && return 0
  fi

  # If no package manager found, try alternative commands
  if echo "$output" | grep -qi "no such file\|not found\|does not exist"; then
    # Try creating parent directory
    local target_dir
    target_dir=$(echo "$cmd" | grep -oP '(?:(?:>|>>)\s*)?/?\S+' | head -1)
    target_dir=$(dirname "$target_dir" 2>/dev/null)
    [ -n "$target_dir" ] && [ ! -d "$target_dir" ] && mkdir -p "$target_dir" 2>/dev/null
    echo "$cmd" && return 0
  fi

  # For flag-based errors, try common fixes
  if echo "$output" | grep -qi "invalid option\|unrecognized\|unknown option"; then
    # Try adding --force or -y
    local fixed="$cmd"
    echo "$fixed" | grep -q "\-\-force" || fixed="$cmd --force"
    echo "$fixed" | grep -q "\-y" || fixed="$fixed -y"
    echo "$fixed" && return 0
  fi

  echo "$cmd"
  return 0
}

_tool_read() {
  local data="$1"
  local path
  path=$(echo "$data" | jq -r '.path // empty')
  local lines
  lines=$(echo "$data" | jq -r '.lines // empty')

  [ -z "$path" ] && { echo '{"error":"No path specified"}'; return 1; }
  [ ! -f "$path" ] && { echo "File not found: $path"; return 1; }

  _log_info "Reading: $path"

  if [ -n "$lines" ] && [ "$lines" != "null" ]; then
    # Support line ranges like "10-20" or "10"
    if echo "$lines" | grep -q '-'; then
      local start_line end_line
      start_line=$(echo "$lines" | cut -d- -f1)
      end_line=$(echo "$lines" | cut -d- -f2)
      sed -n "${start_line},${end_line}p" "$path" 2>/dev/null
    else
      head -n "$lines" "$path" 2>/dev/null
    fi
  else
    cat "$path" 2>/dev/null
  fi

  local size
  size=$(wc -c < "$path" 2>/dev/null)
  _log_debug "Read file: $path ($size bytes)"
  return 0
}

_tool_write() {
  local data="$1"
  local path
  path=$(echo "$data" | jq -r '.path // empty')
  local content
  content=$(echo "$data" | jq -r '.content // empty')
  local append
  append=$(echo "$data" | jq -r '.append // "false"')

  [ -z "$path" ] && { echo '{"error":"No path specified"}'; return 1; }

  local dir
  dir=$(dirname "$path")
  [ ! -d "$dir" ] && mkdir -p "$dir" 2>/dev/null

  if [ "$append" = "true" ] || [ "$append" = "yes" ]; then
    echo "$content" >> "$path"
    _log_info "Appended to: $path"
  else
    echo "$content" > "$path"
    _log_info "Wrote: $path"
  fi

  echo "Written $path"
  return 0
}

_tool_list_dir() {
  local data="$1"
  local path
  path=$(echo "$data" | jq -r '.path // "."')
  local depth
  depth=$(echo "$data" | jq -r '.depth // "1"')
  local show_hidden
  show_hidden=$(echo "$data" | jq -r '.hidden // "false"')

  [ ! -d "$path" ] && { echo "Directory not found: $path"; return 1; }

  if [ "$show_hidden" = "true" ] || [ "$show_hidden" = "yes" ]; then
    find "$path" -maxdepth "$depth" 2>/dev/null | sort
  else
    find "$path" -maxdepth "$depth" -not -name '.*' 2>/dev/null | sort
  fi
  return 0
}

_tool_grep() {
  local data="$1"
  local pattern
  pattern=$(echo "$data" | jq -r '.pattern // empty')
  local path
  path=$(echo "$data" | jq -r '.path // "."')
  local context
  context=$(echo "$data" | jq -r '.context // "2"')

  [ -z "$pattern" ] && { echo '{"error":"No pattern specified"}'; return 1; }

  grep -rn --color=never -C "$context" "$pattern" "$path" 2>/dev/null | head -100
  return 0
}

_tool_find() {
  local data="$1"
  local path
  path=$(echo "$data" | jq -r '.path // "."')
  local name
  name=$(echo "$data" | jq -r '.name // empty')
  local type
  type=$(echo "$data" | jq -r '.type // empty')
  local max_depth
  max_depth=$(echo "$data" | jq -r '.max_depth // "5"')

  local find_args=()
  find_args+=("-maxdepth" "$max_depth")

  if [ -n "$type" ]; then
    find_args+=("-type" "$type")
  fi

  if [ -n "$name" ]; then
    find_args+=("-name" "$name")
  fi

  find "$path" "${find_args[@]}" 2>/dev/null | head -100
  return 0
}

_tool_system_info() {
  echo "**System Information**"
  echo "OS: $(uname -a 2>/dev/null)"
  echo "User: $(whoami 2>/dev/null)"
  echo "Host: $(hostname 2>/dev/null)"
  echo "PWD: $(pwd)"
  echo "Shell: $SHELL"
  echo "Termux: $(command -v termux-info &>/dev/null && termux-info 2>/dev/null | head -3 || echo "N/A")"
  echo ""
  echo "**Resources**"
  echo "Memory: $(free -h 2>/dev/null | head -2 || echo "N/A")"
  echo "Disk: $(df -h . 2>/dev/null | tail -1 || echo "N/A")"
  echo ""
  echo "**CAF Config**"
  echo "Provider: $CAF_PROVIDER"
  echo "Model: $CAF_MODEL"
  echo "Plugins: $CAF_PLUGINS_ENABLED ($(echo ${#TOOL_REGISTRY[@]}) tools)"
  echo "Memory: $(echo "$HISTORY" | jq length) messages"
  return 0
}

_tool_finish() {
  local data="$1"
  local message
  message=$(echo "$data" | jq -r '.message // "Task complete"')
  echo "✅ $message"
  _memory_save_session "autosave"
  return 0
}

_tool_think() {
  local data="$1"
  local thoughts
  thoughts=$(echo "$data" | jq -r '.thoughts // .content // "..."')

  echo -e "${C_DIM}💭 Thinking: $thoughts${C_RESET}"
  _memory_add "assistant" "[Thinking: $thoughts]"
  return 0
}

_tool_session() {
  local data="$1"
  local action
  action=$(echo "$data" | jq -r '.action // "list"')
  local name
  name=$(echo "$data" | jq -r '.name // empty')

  case "$action" in
    save)
      _memory_save_session "$name"
      ;;
    load)
      _memory_load_session "$name"
      ;;
    list|ls)
      _memory_list_sessions
      ;;
    clear)
      _memory_clear
      echo "History cleared."
      ;;
    *)
      echo "Session actions: save, load, list, clear"
      ;;
  esac
  return 0
}

_tool_help() {
  echo "**CAF v2.0 - Available Tools**"
  echo ""
  echo "Built-in tools:"
  echo "  run       - Execute a shell command"
  echo "  read      - Read a file"
  echo "  write     - Write to a file"
  echo "  append    - Append to a file"
  echo "  list_dir  - List directory contents"
  echo "  grep      - Search for text in files"
  echo "  find      - Find files by pattern"
  echo "  system_info - Get system information"
  echo "  think     - Show thinking process"
  echo "  session   - Manage conversation sessions"
  echo "  help      - Show this help"
  echo "  finish    - Complete the task"
  echo "  execute   - Alias for run"
  echo "  read_file - Alias for read"
  echo "  write_file - Alias for write"
  echo "  append_file - Alias for append"
  echo "  search_files - Alias for grep"
  echo "  list      - Alias for list_dir"
  echo ""
  echo "Plugin tools:"
  for tool in $(echo "${!TOOL_REGISTRY[@]}" | tr ' ' '\n' | sort); do
    echo "  $tool"
  done
  echo ""
  echo "Special commands:"
  echo "  /help      - Show this help"
  echo "  /auto      - Toggle autonomous mode"
  echo "  /clear     - Clear conversation history"
  echo "  /save <n>  - Save session"
  echo "  /load <n>  - Load session"
  echo "  /sessions  - List sessions"
  echo "  /model     - Show current model"
  echo "  /plugins   - List loaded plugins"
  echo "  /config    - Show config"
  echo "  /stats     - Show session stats"
  return 0
}

# ============================================
# REGISTER BUILT-IN TOOLS
# ============================================

# Extract a parameter from tool data (handles both JSON and raw strings)
_extract_param() {
  local data="$1"
  local key="$2"
  local fallback="$3"
  local val
  val=$(echo "$data" | jq -r ".${key} // empty" 2>/dev/null)
  if [ -n "$val" ] && [ "$val" != "null" ]; then
    echo "$val"
  else
    echo "$fallback"
  fi
}

_register_builtins() {
  register_tool "run"        "_tool_run"
  register_tool "execute"    "_tool_run"
  register_tool "read"       "_tool_read"
  register_tool "read_file"  "_tool_read"
  register_tool "write"      "_tool_write"
  register_tool "write_file" "_tool_write"
  register_tool "append"     "_tool_write"
  register_tool "append_file" "_tool_write"
  register_tool "list_dir"   "_tool_list_dir"
  register_tool "list"       "_tool_list_dir"
  register_tool "grep"       "_tool_grep"
  register_tool "search_files" "_tool_grep"
  register_tool "find"       "_tool_find"
  register_tool "system_info" "_tool_system_info"
  register_tool "think"      "_tool_think"
  register_tool "session"    "_tool_session"
  register_tool "help"       "_tool_help"
  register_tool "finish"     "_tool_finish"
}

# ============================================
# SYSTEM PROMPT BUILDING
# ============================================

_build_system_prompt() {
  local tool_list=""
  local tool_name

  for tool_name in $(echo "${!TOOL_REGISTRY[@]}" | tr ' ' '\n' | sort -u); do
    tool_list="$tool_list
- $tool_name"
  done

  cat << PROMPT
You are CAF v2.0, an advanced terminal coding agent for Termux/Linux.

You use available tools to solve tasks. Always output valid JSON for tool calls.

AVAILABLE TOOLS:$tool_list

Built-in tool details:

1. run/execute:
   {"tool":"run","data":{"command":"bash command","description":"what this does","timeout":60,"retry":"auto"}}

2. read/read_file:
   {"tool":"read","data":{"path":"/path/to/file","lines":50}}

3. write/write_file:
   {"tool":"write","data":{"path":"/path/to/file","content":"file content"}}

4. append/append_file:
   {"tool":"append","data":{"path":"/path/to/file","content":"content to append"}}

5. list_dir/list:
   {"tool":"list","data":{"path":".","depth":2,"hidden":false}}

6. grep/search_files:
   {"tool":"grep","data":{"pattern":"search text","path":".","context":2}}

7. find:
   {"tool":"find","data":{"path":".","name":"*.py","type":"f","max_depth":5}}

8. system_info:
   {"tool":"system_info","data":{}}

9. think:
   {"tool":"think","data":{"thoughts":"Your reasoning here"}}

10. finish:
    {"tool":"finish","data":{"message":"Task complete"}}

11. help:
    {"tool":"help","data":{}}

12. session:
    {"tool":"session","data":{"action":"save|load|list|clear","name":"..."}}

For non-tool responses (chat, explanation, code review), respond with plain text or markdown.

RULES:
- NEVER guess file contents; ALWAYS read before editing
- ALWAYS verify commands after running them
- Keep edits minimal and focused
- Work step-by-step
- Use \`think\` to show your reasoning
- Prefer \`run\` with \`timeout\` for long commands
- When commands fail, self-healing will auto-retry with fixes
- Use \`finish\` when the task is complete
- Use the search tool for web lookups
- Use the project index tools for codebase navigation
PROMPT
}

# ============================================
# MODEL API CALLS (with streaming)
# ============================================

# Get the API URL and auth header for the configured provider
_api_config() {
  case "$CAF_PROVIDER" in
    openrouter)
      echo "url=$CAF_OPENROUTER_URL"
      echo "auth_header=\"Bearer $OPENROUTER_API_KEY\""
      ;;
    openai)
      echo "url=$CAF_OPENAI_URL"
      echo "auth_header=\"Bearer $OPENAI_API_KEY\""
      ;;
    ollama)
      echo "url=$CAF_OLLAMA_URL"
      echo "auth_header="
      ;;
    nvidia)
      echo "url=$CAF_NVIDIA_URL"
      echo "auth_header=\"Bearer $NVIDIA_API_KEY\""
      ;;
    *)
      echo "url=$CAF_OPENROUTER_URL"
      echo "auth_header=\"Bearer $OPENROUTER_API_KEY\""
      ;;
  esac
}

# Build the API payload JSON
_api_payload() {
  local stream="$1"

  case "$CAF_PROVIDER" in
    openrouter|openai|nvidia)
      jq -n \
        --arg model "$CAF_MODEL" \
        --argjson msgs "$HISTORY" \
        --argjson temp "$CAF_TEMPERATURE" \
        --argjson max_tokens "$CAF_MAX_TOKENS" \
        --argjson stream "$stream" \
        '{
          model:$model,
          messages:$msgs,
          temperature:$temp,
          max_tokens:$max_tokens,
          stream:$stream
        }'
      ;;
    anthropic)
      # Extract messages (Anthropic uses system != messages)
      local system_content
      system_content=$(echo "$HISTORY" | jq -r '[.[] | select(.role=="system") | .content] | join("\n")')
      local msgs
      msgs=$(echo "$HISTORY" | jq '[.[] | select(.role!="system")]')
      jq -n \
        --arg model "$CAF_MODEL" \
        --argjson msgs "$msgs" \
        --arg system "$system_content" \
        --argjson temp "$CAF_TEMPERATURE" \
        --argjson max_tokens "$CAF_MAX_TOKENS" \
        --argjson stream "$stream" \
        '{
          model:$model,
          messages:$msgs,
          system:$system,
          temperature:$temp,
          max_tokens:$max_tokens,
          stream:$stream
        }'
      ;;
    ollama)
      jq -n \
        --arg model "$CAF_MODEL" \
        --argjson msgs "$HISTORY" \
        --argjson temp "$CAF_TEMPERATURE" \
        --argjson stream "$stream" \
        '{
          model:$model,
          messages:$msgs,
          options: {temperature:$temp},
          stream:$stream
        }'
      ;;
  esac
}

# Non-streaming API call
_api_call() {
  local url auth_header payload

  eval "$(_api_config)"
  payload=$(_api_payload false)

  _log_debug "API request model=$CAF_MODEL provider=$CAF_PROVIDER"

  local response
  response=$(curl -s --max-time 60 \
    -H "Authorization: $auth_header" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$url" 2>&1)

  local http_code="$?"

  if [ "$http_code" -ne 0 ]; then
    _log_error "API request failed (curl exit: $http_code)"
    echo "$response"
    return 1
  fi

  # Extract content
  local content
  content=$(echo "$response" | jq -r '.choices[0].message.content // .content // .message.content // empty' 2>/dev/null)

  if [ -z "$content" ]; then
    _log_error "Empty response from API"
    _log_debug "Response: $(echo "$response" | head -c 500)"
    echo ""
    return 1
  fi

  echo "$content"
  return 0
}

# Streaming API call
_api_call_stream() {
  mkdir -p "$CAF_TEMP_DIR" 2>/dev/null
  local url auth_header payload

  eval "$(_api_config)"
  payload=$(_api_payload true)

  _log_debug "Streaming API request model=$CAF_MODEL provider=$CAF_PROVIDER"

  # Use curl with buffering off for streaming
  local temp_out
  temp_out=$(mktemp "$CAF_TEMP_DIR/stream_out.XXXXXX")
  if [ -z "$temp_out" ] || [ ! -f "$temp_out" ]; then
    _log_warn "Cannot create temp file, falling back to non-streaming"
    _api_call
    return $?
  fi

  # Temp files for control flow
  local finish_marker
  finish_marker=$(mktemp "$CAF_TEMP_DIR/stream_finish.XXXXXX")
  if [ -z "$finish_marker" ] || [ ! -f "$finish_marker" ]; then
    _log_warn "Cannot create temp file"
    _api_call
    return $?
  fi

  # Start streaming curl in background
  curl -s --no-buffer --max-time 120 \
    -H "Authorization: $auth_header" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$url" 2>/dev/null | while IFS= read -r line; do
      # SSE format: "data: {...}"
      if echo "$line" | grep -q "^data: "; then
        local json_part
        json_part="${line#data: }"

        # "[DONE]" signal
        if [ "$json_part" = "[DONE]" ]; then
          touch "$finish_marker"
          break
        fi

        # Extract content delta
        local delta
        delta=$(echo "$json_part" | jq -r '.choices[0].delta.reasoning // .choices[0].delta.reasoning_content // .choices[0].delta.content // .choices[0].text // .message.content // empty' 2>/dev/null)

        if [ -n "$delta" ] && [ "$delta" != "null" ]; then
          printf '%s' "$delta" >&2
          # Append to temp for full content
          printf '%s' "$delta" >> "$temp_out"
        fi
      fi
    done

  # If finish marker wasn't set (non-SSE response), try regular JSON parse
  if [ ! -f "$finish_marker" ]; then
    local content
    content=$(cat "$temp_out" 2>/dev/null)
    if [ -z "$content" ]; then
      _log_warn "Stream produced no output, falling back to non-streaming"
      _api_call
    fi
  fi

  # Output full content to stdout for return value
  cat "$temp_out" 2>/dev/null

  # Cleanup
  rm -f "$temp_out" "$finish_marker" 2>/dev/null
}

# ============================================
# PARSE AND HANDLE MODEL RESPONSE
# ============================================

_handle_response() {
  local content="$1"

  [ -z "$content" ] && return 0

  # Check if the response is a JSON tool call
  local is_json
  is_json=$(echo "$content" | jq -e '.tool // empty' 2>/dev/null)

  if [ -n "$is_json" ] && [ "$is_json" != "null" ]; then
    local tool_name data
    tool_name=$(echo "$content" | jq -r '.tool // empty')
    data=$(echo "$content" | jq -c '.data // {}')

    if [ -n "$tool_name" ]; then
      _log_info "Tool call: $tool_name"
      _memory_add "assistant" "$content"

      # Execute tool
      local result
      result=$(_tool_dispatch "$tool_name" "$data")
      local rc=$?

      # Add result to history
      local result_msg
      result_msg="Tool '$tool_name' completed (exit: $rc):\n$(echo "$result" | head -c 2000)"
      _memory_add "user" "$result_msg"

      # Print result
      echo ""
      echo -e "${C_CYAN}═══════════════════════════════════════${C_RESET}"
      echo -e "${C_BOLD}📋 Tool Result:${C_RESET}"
      echo "$result"
      echo -e "${C_CYAN}═══════════════════════════════════════${C_RESET}"
      echo ""

      return 0
    fi
  fi

  # Plain text response (chat, explanation, etc.)
  _memory_add "assistant" "$content"

  # In streaming mode, content was already displayed via stderr
  # Only print in non-streaming mode
  if [ "$CAF_STREAM" != "true" ]; then
    echo "$content"
  fi
  return 0
}

# ============================================
# AUTO-RETRY LOOP FOR TOOL EXECUTION
# ============================================

_auto_loop() {
  local max_iterations="${1:-50}"
  local iteration=0

  while [ "$iteration" -lt "$max_iterations" ]; do
    iteration=$((iteration + 1))
    _log_debug "Auto-loop iteration $iteration"

    # Call model
    local response
    if [ "$CAF_STREAM" = "true" ]; then
      response=$(_api_call_stream)
    else
      response=$(_api_call)
    fi

    [ -z "$response" ] && { _log_warn "Empty response, breaking"; break; }

    echo ""
    _handle_response "$response"
    echo ""

    # Check if the last response was a finish signal
    local last_msg
    last_msg=$(echo "$HISTORY" | jq -r '.[-1].content // empty')
    if echo "$last_msg" | grep -qi "\"tool\":\"finish\""; then
      _log_info "Finish signal detected, ending auto-loop"
      break
    fi

    # Check if response contains finish
    if echo "$response" | jq -e '.tool=="finish"' &>/dev/null; then
      _log_info "Tool finish called, ending auto-loop"
      break
    fi
  done
}

# ============================================
# AGENT MODE - Autonomous execution
# ============================================

_agent_mode() {
  local task="$1"

  _log_info "Agent mode engaged. Task: $task"

  # Add the task to history
  _memory_add "user" "$task"

  # Run auto loop
  _auto_loop 30

  _memory_save_session "agent-$(date +%Y%m%d-%H%M%S)"
  _log_info "Agent mode complete"
}

# ============================================
# COMMAND-LINE INTERFACE
# ============================================

_cli_usage() {
  cat << USAGE
CAF v2.0 - Advanced Terminal Coding Agent

Usage:
  caf.sh                      Interactive mode
  caf.sh "query"              Single query mode
  caf.sh --agent "task"       Autonomous agent mode
  caf.sh --session "name"     Continue a saved session
  caf.sh --help               Show this help

Environment:
  OPENROUTER_API_KEY   API key (required for openrouter)
  CAF_MODEL            Model name (default: openai/gpt-4o-mini:free)
  CAF_PROVIDER         Provider (openrouter|openai|anthropic|ollama|nvidia)
  CAF_AUTO=1           Start in autonomous mode
  CAF_STREAM=true/false Enable streaming output

Commands in interactive mode:
  exit              Exit
  auto              Toggle autonomous mode
  /help             Show tool help
  /clear            Clear conversation
  /save <name>      Save session
  /load <name>      Load session
  /sessions         List sessions
  /stats            Show stats
USAGE
}

# ============================================
# INTERACTIVE MAIN LOOP
# ============================================

_main_interactive() {
  mkdir -p "$CAF_TEMP_DIR" "$CAF_MEMORY_DIR" 2>/dev/null
  echo ""
  echo -e "${C_GREEN}${C_BOLD}╔══════════════════════════════════════╗${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}║     CAF v2.0 - Coding Agent         ║${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}║     ${C_CYAN}Self-healing • Streaming • Plugins${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}╚══════════════════════════════════════╝${C_RESET}"
  echo ""
  echo -e "${C_DIM}Model:${C_RESET} $CAF_MODEL"
  echo -e "${C_DIM}Provider:${C_RESET} $CAF_PROVIDER"
  echo -e "${C_DIM}Plugins:${C_RESET} $(echo ${#TOOL_REGISTRY[@]}) tools loaded"
  echo -e "${C_DIM}Memory:${C_RESET} $(echo "$HISTORY" | jq length) messages"
  echo ""
  echo -e "${C_DIM}Type 'exit' to quit | 'auto' to toggle autonomous mode | '/help' for tools${C_RESET}"
  echo ""

  while true; do
    local auto_ind=""
    [ "$CAF_AUTO" -eq 1 ] && auto_ind=" [AUTO]"

    echo -ne "${C_BOLD}${C_GREEN}${CAF_PROMPT}>${C_RESET}${auto_ind} "
    read -r input

    # Handle special commands
    case "$input" in
      exit|quit)
        _memory_save_session "autosave"
        echo "Goodbye!"
        break
        ;;
      auto)
        CAF_AUTO=$((1 - CAF_AUTO))
        echo "Autonomous mode: $([ "$CAF_AUTO" -eq 1 ] && echo 'ON' || echo 'OFF')"
        continue
        ;;
      /help)
        _tool_help ""
        continue
        ;;
      /clear)
        _memory_clear
        echo "History cleared."
        continue
        ;;
      /save*)
        local sname="${input#/save }"
        [ -z "$sname" ] && sname="manual-$(date +%Y%m%d-%H%M%S)"
        _memory_save_session "$sname"
        continue
        ;;
      /load*)
        local lname="${input#/load }"
        _memory_load_session "$lname"
        continue
        ;;
      /sessions)
        _memory_list_sessions
        continue
        ;;
      /stats)
        echo "**Session Stats**"
        echo "Messages: $(echo "$HISTORY" | jq length)"
        echo "Tokens used: 0 (tracking not implemented)"
        echo "Plugins: $(echo ${#TOOL_REGISTRY[@]}) tools"
        continue
        ;;
      /model)
        echo "Model: $CAF_MODEL ($CAF_PROVIDER)"
        continue
        ;;
      /plugins)
        echo "**Loaded Plugins/Tools**"
        for t in $(echo "${!TOOL_REGISTRY[@]}" | tr ' ' '\n' | sort); do
          echo "  - $t"
        done
        continue
        ;;
      /config)
        echo "**CAF Configuration**"
        env | grep ^CAF_ | sort | while IFS='=' read -r k v; do
          echo "  $k=${v:0:80}"
        done
        continue
        ;;
      ""|" ")
        continue
        ;;
    esac

    # Normal input - add to history
    _memory_add "user" "$input"

    if [ "$CAF_AUTO" -eq 1 ]; then
      _auto_loop
    else
      # Single response
      local response
      if [ "$CAF_STREAM" = "true" ]; then
        echo -e "${C_DIM}── Response ──${C_RESET}"
        response=$(_api_call_stream)
        echo ""
        echo -e "${C_DIM}──────────────${C_RESET}"
      else
        response=$(_api_call)
        _handle_response "$response"
      fi
    fi

    echo ""
  done
}

# ============================================
# MAIN ENTRY POINT
# ============================================

_main() {
  # Initialize
  # Skip deps check for help
  case "${1:-}" in --help|-h|--version|-v) _cli_usage; return 0;; esac
  _init_deps
  _register_builtins
  _plugins_load
  _memory_load

  # Build system prompt if history is empty
  local hist_len
  hist_len=$(echo "$HISTORY" | jq length)
  if [ "$hist_len" -eq 0 ]; then
    local sys_prompt
    sys_prompt=$(_build_system_prompt)
    HISTORY=$(echo '[]' | jq --arg sys "$sys_prompt" '. + [{"role":"system","content":$sys}]')
    _memory_save
  fi

  # Parse arguments
  case "${1:-}" in
    --help|-h)
      _cli_usage
      ;;
    --agent|-a)
      shift
      _agent_mode "$*"
      ;;
    --session|-s)
      shift
      _memory_load_session "$1"
      shift
      if [ -n "$*" ]; then
        _memory_add "user" "$*"
        _auto_loop
      else
        _main_interactive
      fi
      ;;
    --version|-v)
      echo "CAF v2.0"
      ;;
    *)
      if [ -n "$*" ]; then
        # Single query mode
        _memory_add "user" "$*"
        local response
        if [ "$CAF_STREAM" = "true" ]; then
          response=$(_api_call_stream)
          echo ""
        else
          response=$(_api_call)
        fi
        [ -n "$response" ] && _handle_response "$response"
      else
        _main_interactive
      fi
      ;;
  esac
}

_main "$@"
