#############################################
# CAF Plugin: Git Tools
# Provides: git_diff, git_log, git_blame, git_status
#############################################

plugin_git_tools_init() {
  register_tool "git_diff"   "tool_git_diff"
  register_tool "git_log"    "tool_git_log"
  register_tool "git_blame"  "tool_git_blame"
  register_tool "git_status" "tool_git_status"
  return 0
}

#############################################
# Show git diff for a file
#############################################
tool_git_diff() {
  local file="$1"
  local staged="${2:-false}"
  local lines="${3:-$CAF_DIFF_CONTEXT}"

  if [ "$staged" = "true" ] || [ "$staged" = "yes" ] || [ "$staged" = "--staged" ]; then
    git diff --cached "$file" 2>&1 | head -100
  elif [ -n "$file" ]; then
    git diff "$file" 2>&1 | head -100
  else
    git diff 2>&1 | head -200
  fi
  return 0
}

#############################################
# Show git log
#############################################
tool_git_log() {
  local count="${1:-10}"
  local file="$2"

  if [ -n "$file" ]; then
    git log --oneline --graph --decorate -"$count" -- "$file" 2>&1
  else
    git log --oneline --graph --decorate -"$count" 2>&1
  fi
  return 0
}

#############################################
# Git blame for a file
#############################################
tool_git_blame() {
  local file="$1"
  local lines="${2:-}"

  if [ -z "$file" ]; then
    log_error "git_blame: file path required"
    return 1
  fi

  if [ ! -f "$file" ]; then
    log_error "File not found: $file"
    return 1
  fi

  if [ -n "$lines" ]; then
    git blame -L "$lines" "$file" 2>&1
  else
    git blame "$file" 2>&1
  fi
  return 0
}

#############################################
# Git status summary
#############################################
tool_git_status() {
  local path="${1:-.}"

  if ! git -C "$path" rev-parse --git-dir &>/dev/null; then
    echo "Not a git repository."
    return 1
  fi

  echo "**Git Status**"
  echo ""
  echo "Branch: $(git -C "$path" branch --show-current 2>/dev/null)"
  echo ""
  echo "Changes:"
  git -C "$path" status --short 2>&1
  echo ""
  echo "Recent commits:"
  git -C "$path" log --oneline -5 2>&1
  return 0
}

plugin_git_tools_init
