# CAF v2.0 - Advanced Terminal Coding Agent

Self-healing, streaming, plugin-powered coding agent for Termux/Linux.

## Quick Start

```bash
# 1. Set your API key
export OPENROUTER_API_KEY="sk-or-..."

# 2. Run CAF
~/caf.sh

# Or provide a task directly
~/caf.sh "find all Python files and count lines"
```

## Features

### 🧠 Self-Healing
When commands fail, CAF automatically detects the error (missing command, permission denied, network issues, syntax errors) and attempts to fix it:
- Installs missing packages via `pkg`/`apt`/`apk`
- Adds execute permissions on permission errors
- Creates missing directories
- Retries with `--force` or `-y` flags
- Configurable retry count (`CAF_AUTO_RETRY=3`)

### 🎯 Long-Term Memory Compression
Conversation history is automatically compressed when it grows beyond a threshold:
- Summarizes older messages into a compact form
- Preserves key topics and context
- Keeps recent messages (last 20) intact
- Configurable threshold (`CAF_COMPRESSION_THRESHOLD=50`)
- Session save/load for long-running work

### 🌐 Web Search
Search the web and fetch URL contents directly from the agent:
- DuckDuckGo backend (no API key needed)
- Configurable search providers (DuckDuckGo, SearXNG)
- Structured results saved for tool consumption
- URL content fetching with HTML stripping

### 🔌 Plugin System
Extend CAF with custom tools and capabilities:
- Drop `.sh` files in `~/.caf/plugins/`
- Register tools via `register_tool name handler_function`
- Built-in plugins: Web Search, Project Index, Background Tasks, Git Tools, Self-Healing
- Plugin registry at `~/.caf/plugins/registry.json`

### 📂 Project Indexing (VSCode-like)
Build a searchable index of your project:
- Scans files and builds a symbol database
- Supports: Python, JS/TS, Go, Rust, C/C++, Java, Shell, Markdown
- Quick file finding and symbol search
- File type statistics
- Poll-based file watching
- Ignore patterns for `.git`, `node_modules`, etc.

### 🔄 Auto-Retry Failed Commands
Intelligent retry with context-aware fixes:
- Analyzes error output to determine failure type
- Applies targeted fixes before retrying
- Configurable max retries and delay
- Self-healing modifies the command to fix issues

### ⚡ Background Task Mode
Run long commands without blocking:
- `bg <cmd>` - Run command in background
- `bg_list` - List all tasks
- `bg_result <id>` - Get task output
- `bg_cancel <id>` - Cancel a task
- `bg_wait <id>` - Wait for completion
- Persistent task storage with metadata

### 📺 Streaming Output
Real-time token-by-token output from the model:
- SSE streaming via `curl --no-buffer`
- Faster perceived response times
- Configurable via `CAF_STREAM=true/false`

### 🛠️ Additional Features
- **Multiple providers**: OpenRouter, OpenAI, Anthropic, Ollama
- **Session management**: save/load/resume conversations
- **Autonomous mode**: agent loops until task is done
- **Dangerous command protection**: confirm before risky operations
- **Configurable everything**: via `~/.caf/config.sh`
- **Colorful terminal output**: clear visual feedback
- **Git integration**: diff, log, blame, status
- **Error diagnosis**: explain what went wrong

## Configuration

All settings are in `~/.caf/config.sh` or environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CAF_PROVIDER` | `openrouter` | API provider |
| `CAF_MODEL` | `openai/gpt-4o-mini:free` | Model name |
| `CAF_STREAM` | `true` | Enable streaming |
| `CAF_AUTO_RETRY` | `3` | Max retries for commands |
| `CAF_COMPRESSION_THRESHOLD` | `50` | Messages before compression |
| `CAF_MAX_HISTORY` | `100` | Max history messages |
| `CAF_SELF_HEAL` | `true` | Enable self-healing |
| `CAF_TIMEOUT` | `60` | Command timeout (s) |
| `CAF_COLOR` | `true` | Colored output |

## Architecture

```
~/.caf/
├── config.sh           # Configuration
├── .env                # Local environment variables
├── plugins/
│   ├── registry.json   # Plugin manifest
│   ├── web-search.sh   # Web search tools
│   ├── project-index.sh# Project indexing tools
│   ├── bg-tasks.sh     # Background task tools
│   ├── git-tools.sh    # Git integration tools
│   └── self-heal.sh    # Self-healing tools
├── memory/
│   ├── history.json    # Conversation history
│   └── summaries.json  # Compressed summaries
├── sessions/           # Saved sessions
├── index/              # Project indexes
├── tasks/              # Background task data
└── cache/              # Response cache
```

## Built-in Tools

- `run` - Execute shell commands
- `read` / `read_file` - Read files
- `write` / `write_file` - Write files
- `append` / `append_file` - Append to files
- `list_dir` / `list` - List directories
- `grep` / `search_files` - Search file contents
- `find` - Find files by pattern
- `system_info` - System information
- `think` - Show reasoning process
- `session` - Manage conversation sessions
- `help` - Tool reference
- `finish` - Complete task

## Plugin Tools (loaded on startup)

- `search` - Web search (DuckDuckGo)
- `fetch_url` - Fetch URL contents
- `index_project` - Build project index
- `search_symbols` - Find symbols in code
- `find_file` - Quick file finder
- `index_status` - Show index status
- `watch_project` - Watch for file changes
- `bg` / `bg_list` / `bg_result` / `bg_cancel` / `bg_wait` - Background tasks
- `git_diff` / `git_log` / `git_blame` / `git_status` - Git tools
- `heal` / `diagnose` - Self-healing tools

## Creating Plugins

Create a `.sh` file in `~/.caf/plugins/`:

```bash
#!/usr/bin/env bash
# my-plugin.sh

my_plugin_init() {
  register_tool "my_tool" "tool_my_tool"
}

tool_my_tool() {
  local data="$1"
  echo "Hello from my plugin! Data: $data"
}

my_plugin_init
```
