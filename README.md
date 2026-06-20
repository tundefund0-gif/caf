# CAF v2.0 — Advanced Terminal Coding Agent

**CAF** (Coding Agent Framework) is a self-healing, streaming, plugin-powered terminal coding agent built for **Termux** and **Linux**. It turns your phone or terminal into an AI-powered development assistant.

```
  ╔══════════════════════════════════════╗
  ║     CAF v2.0 - Coding Agent         ║
  ║  Self-healing • Streaming • Plugins  ║
  ╚══════════════════════════════════════╝
```

---

## Features

| Feature | Description |
|---|---|
| **🧠 Self-Healing** | Auto-detects command failures (missing packages, permission denied, syntax errors) and fixes them — installs dependencies, adds execute permissions, retries with flags |
| **💾 Long-Term Memory** | Conversation history auto-compresses via summarization when it grows too large, preserving key context while keeping recent messages intact |
| **🌐 Web Search** | DuckDuckGo search and URL fetching — no API key needed |
| **🔌 Plugin System** | Extend functionality by dropping `.sh` files into `~/.caf/plugins/`. Tools auto-register and become available to the AI |
| **📂 Project Indexing** | VSCode-like workspace index with symbol search across Python, JS/TS, Go, Rust, C/C++, Java, Shell, Markdown |
| **🔄 Auto-Retry** | Failed commands are retried with context-aware fixes (install missing tools, fix permissions, create directories) |
| **⚡ Background Tasks** | Run commands in the background: `bg`, `bg_list`, `bg_result`, `bg_cancel`, `bg_wait` |
| **📺 Streaming Output** | Real-time token-by-token display as the model generates responses |
| **🔐 Dangerous Command Protection** | Confirms before executing risky operations (`rm`, `dd`, `mkfs`, etc.) |
| **💾 Session Management** | Save, load, and resume conversation sessions |
| **🔄 Git Integration** | Built-in tools: `git_diff`, `git_log`, `git_blame`, `git_status` |

---

## Installation

### Requirements

- **bash** 4.x+
- **curl** — for API calls
- **jq** — for JSON processing
- An API key from one of the supported providers:
  - [OpenRouter](https://openrouter.ai/) (free tier available)
  - [NVIDIA](https://build.nvidia.com/) (free API credits)
  - OpenAI, Anthropic, or local Ollama

### Install on Any Device (ARM/ARM64/x86)

```bash
# 1. Install dependencies (Termux)
pkg install curl jq git

# 1. Install dependencies (Debian/Ubuntu)
sudo apt install curl jq git

# 2. Clone the repo
git clone https://github.com/tundefund0-gif/caf.git

# 3. Set your API key
export OPENROUTER_API_KEY="sk-or-..."
# OR for NVIDIA:
export NVIDIA_API_KEY="nvapi-..."

# 4. Run it
cd caf
bash caf.sh
```

### Install on 32-bit ARMv7 (armv7l) Phones

CAF runs perfectly on **32-bit ARM (armv7l)** devices — this includes many older Android phones. The script and all dependencies are fully supported on 32-bit ARM.

**Step-by-step for ARMv7 Termux:**

```bash
# Install Termux from F-Droid (NOT Play Store — Play Store version is outdated)
# https://f-droid.org/packages/com.termux/

# Open Termux and run:
pkg update && pkg upgrade -y

# Install dependencies (all available for armv7):
pkg install curl jq git -y

# Clone CAF:
git clone https://github.com/tundefund0-gif/caf.git
cd caf

# Make it executable:
chmod +x caf.sh

# Set your API key:
export NVIDIA_API_KEY="nvapi-your-key-here"

# Run:
bash caf.sh

# Optional: add to PATH for quick access
echo 'export PATH="$PATH:$HOME/caf"' >> ~/.bashrc
echo 'alias caf="bash ~/caf/caf.sh"' >> ~/.bashrc
source ~/.bashrc
# Now you can just type: caf
```

**Troubleshooting ARMv7:**

| Issue | Fix |
|---|---|
| `curl: not found` | `pkg install curl` |
| `jq: not found` | `pkg install jq` — if unavailable, try `pkg install jq-static` or use the [official jq binary](https://stedolan.github.io/jq/download/) |
| `git: not found` | `pkg install git` |
| Permission denied | `chmod +x caf.sh` |
| `jq` crashes on ARMv7 | Install pre-compiled binary: `wget -O $PREFIX/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-arm32` then `chmod +x $PREFIX/bin/jq` |
| Slow performance | Use smaller models like `openai/gpt-4o-mini:free` or `nvidia/nemotron-3-super-120b-a12b` (both fast, even on ARM) |

---

## Quick Start

### Single Query
```bash
bash caf.sh "List all files in the current directory"
```

### Interactive Mode
```bash
bash caf.sh
```
Then type queries like chatting with an AI that can run commands.

### Autonomous Agent Mode
```bash
bash caf.sh --agent "Find all Python files, count lines, show the top 5 largest"
```
The agent will loop — running tools, reading results, and continuing until the task is complete.

### Continue a Session
```bash
bash caf.sh --session my_project
```

---

## Configuration

All settings live in `~/.caf/config.sh` or as environment variables:

| Variable | Default | Description |
|---|---|---|
| `CAF_PROVIDER` | `openrouter` | API provider: `openrouter`, `openai`, `anthropic`, `ollama`, `nvidia` |
| `CAF_MODEL` | `openai/gpt-4o-mini:free` | Model name |
| `CAF_STREAM` | `true` | Enable streaming output |
| `CAF_AUTO_RETRY` | `3` | Max retries for failed commands |
| `CAF_SELF_HEAL` | `true` | Enable self-healing on errors |
| `CAF_COMPRESSION_THRESHOLD` | `50` | Messages before memory compression |
| `CAF_TIMEOUT` | `60` | Command timeout (seconds) |
| `CAF_TEMPERATURE` | `0.3` | Model temperature |
| `CAF_MAX_TOKENS` | `4096` | Max response tokens |
| `CAF_COLOR` | `true` | Colored terminal output |
| `CAF_SEARCH_BACKEND` | `duckduckgo` | Web search backend |

---

## Usage Guide

### Built-in Tools

The AI model uses these tools automatically. Provide a clear task and it picks the right tool:

| Tool | Purpose |
|---|---|
| `run` / `execute` | Execute shell commands |
| `read` / `read_file` | Read file contents |
| `write` / `write_file` | Write to files |
| `append` / `append_file` | Append to files |
| `list_dir` / `list` | List directory contents |
| `grep` / `search_files` | Search text in files |
| `find` | Find files by pattern |
| `system_info` | Show system information |
| `think` | Display AI reasoning |
| `session` | Manage sessions |
| `finish` | Complete the task |

### Plugin Tools (auto-loaded)

| Tool | Plugin | Purpose |
|---|---|---|
| `search` | Web Search | Search the web via DuckDuckGo |
| `fetch_url` | Web Search | Fetch and read URL contents |
| `index_project` | Project Index | Build a VSCode-like file index |
| `search_symbols` | Project Index | Find function/class definitions |
| `find_file` | Project Index | Quick file finder |
| `index_status` | Project Index | Show index stats |
| `bg` / `bg_list` / `bg_result` / `bg_cancel` / `bg_wait` | Background Tasks | Background task management |
| `git_diff` / `git_log` / `git_blame` / `git_status` | Git Tools | Git integration |
| `heal` / `diagnose` | Self-Healing | Diagnose and fix errors |

### Interactive Commands

| Command | Action |
|---|---|
| `exit` / `quit` | Exit CAF |
| `auto` | Toggle autonomous mode |
| `/help` | Show all tools |
| `/clear` | Clear conversation |
| `/save <name>` | Save session |
| `/load <name>` | Load session |
| `/sessions` | List sessions |
| `/stats` | Session statistics |
| `/model` | Show active model |
| `/plugins` | List loaded tools |
| `/config` | Show configuration |

---

## Architecture

```
~/.caf/
├── config.sh           # All configuration
├── .env                # Local secrets (not committed)
├── plugins/
│   ├── registry.json   # Plugin manifest
│   ├── web-search.sh   # Web search plugin
│   ├── project-index.sh# Project indexing plugin
│   ├── bg-tasks.sh     # Background tasks plugin
│   ├── git-tools.sh    # Git integration plugin
│   └── self-heal.sh    # Self-healing plugin
├── memory/
│   ├── history.json    # Conversation history
│   └── summaries.json  # Compressed memories
├── sessions/           # Saved session snapshots
├── index/              # Project search indexes
└── tasks/              # Background task data
```

---

## Creating Plugins

Drop a `.sh` file in `~/.caf/plugins/`:

```bash
#!/usr/bin/env bash
# ~/.caf/plugins/my-tool.sh

my_plugin_init() {
  register_tool "my_tool" "tool_my_tool"
}

tool_my_tool() {
  local data="$1"
  echo "Hello from my plugin! Data: $data"
}

my_plugin_init
```

The tool `my_tool` is immediately available to the AI model after CAF restarts.

---

## License

MIT — do whatever you want with it.
