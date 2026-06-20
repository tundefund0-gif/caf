#############################################
# CAF Plugin: Self Healing
# Auto-diagnose and fix common command errors
# Provides: heal, diagnose
#############################################

plugin_self_heal_init() {
  register_tool "heal"     "tool_heal"
  register_tool "diagnose" "tool_diagnose"
  return 0
}

#############################################
# Diagnose what went wrong with a command
#############################################
tool_diagnose() {
  local command="$1"
  local error_output="$2"

  echo "**Diagnosis Report**"
  echo ""
  echo "Command: $command"
  echo ""

  # Check common issues
  if echo "$error_output" | grep -qi "command not found"; then
    local missing_cmd
    missing_cmd=$(echo "$error_output" | grep -oP ".*?:\s+\K\S+" | head -1)
    echo "🔍 Issue: Command not found: $missing_cmd"
    echo "   Fix: Install with pkg/apt/apk or check PATH"
    echo ""
    echo "   Suggestions:"
    echo "   - pkg install $missing_cmd"
    echo "   - apt-get install $missing_cmd"
    echo "   - which $missing_cmd"
  fi

  if echo "$error_output" | grep -qi "permission denied\|permission denied\|not allowed\|denied"; then
    echo "🔍 Issue: Permission denied"
    echo "   Fix: Use chmod or run with elevated privileges"
    echo ""
    echo "   Suggestions:"
    echo "   - chmod +x <file>"
    echo "   - chmod 755 <file>"
    echo "   - Check file ownership"
  fi

  if echo "$error_output" | grep -qi "no such file\|not found\|does not exist\|cannot access"; then
    echo "🔍 Issue: File or directory not found"
    echo "   Fix: Check the path exists"
    echo ""
    echo "   Suggestions:"
    echo "   - ls -la <directory>"
    echo "   - pwd"
    echo "   - Use absolute paths"
  fi

  if echo "$error_output" | grep -qi "network\|connection refused\|could not resolve\|timeout\|timed out"; then
    echo "🔍 Issue: Network error"
    echo "   Fix: Check connectivity"
    echo ""
    echo "   Suggestions:"
    echo "   - ping -c 3 8.8.8.8"
    echo "   - Check proxy settings"
    echo "   - Try again later"
  fi

  if echo "$error_output" | grep -qi "syntax error\|parse error\|unexpected"; then
    echo "🔍 Issue: Syntax error in command"
    echo "   Fix: Check quoting, escaping, and syntax"
    echo ""
    echo "   Suggestions:"
    echo "   - Check quote matching"
    echo "   - Use shellcheck"
    echo "   - Break command into steps"
  fi

  if echo "$error_output" | grep -qi "segmentation fault\|core dump\|SIGSEGV"; then
    echo "🔍 Issue: Segmentation fault (program crashed)"
    echo "   Fix: Use a different approach"
    echo ""
    echo "   Suggestions:"
    echo "   - Check available memory"
    echo "   - Update the program"
    echo "   - Use alternative tool"
  fi

  echo ""
  echo "Raw error output:"
  echo "---"
  echo "$error_output" | head -20
  echo "---"
  return 0
}

#############################################
# Attempt to heal/fix common issues
#############################################
tool_heal() {
  local issue="$1"
  local target="$2"

  echo "**Attempting Auto-Heal**"
  echo ""

  case "$issue" in
    "missing_command"|"command_not_found")
      local cmd="${target:-unknown}"
      echo "Attempting to install: $cmd"

      if command -v pkg &>/dev/null; then
        echo "> pkg install $cmd"
        pkg install -y "$cmd" 2>&1 | tail -5
      elif command -v apt-get &>/dev/null; then
        echo "> apt-get install -y $cmd"
        apt-get install -y "$cmd" 2>&1 | tail -5
      elif command -v apk &>/dev/null; then
        echo "> apk add $cmd"
        apk add "$cmd" 2>&1 | tail -5
      else
        echo "No package manager found. Install '$cmd' manually."
        return 1
      fi

      if command -v "$cmd" &>/dev/null; then
        echo "✅ $cmd installed successfully"
        return 0
      else
        echo "❌ Failed to install $cmd"
        return 1
      fi
      ;;

    "permission"|"permission_denied")
      if [ -f "$target" ]; then
        echo "> chmod +x $target"
        chmod +x "$target" 2>&1
        echo "✅ Added execute permission to $target"
        return 0
      elif [ -d "$target" ]; then
        echo "> chmod 755 $target"
        chmod 755 "$target" 2>&1
        echo "✅ Fixed permissions for $target"
        return 0
      else
        echo "Target not found: $target"
        return 1
      fi
      ;;

    "disk_space"|"disk_full")
      echo "Checking disk space..."
      df -h "$(pwd)" 2>&1
      echo ""
      echo "Cleaning common caches..."
      rm -rf /tmp/caf-* 2>/dev/null
      echo "Cleaned /tmp"
      return 0
      ;;

    "network"|"connection")
      echo "Checking network..."
      echo "> ping -c 2 8.8.8.8"
      ping -c 2 8.8.8.8 2>&1 | tail -3
      echo ""
      echo "> curl -sI https://google.com"
      curl -sI https://google.com 2>&1 | head -3
      return 0
      ;;

    *)
      echo "Unknown issue type: $issue"
      echo "Available: missing_command, permission, disk_space, network"
      return 1
      ;;
  esac
}

plugin_self_heal_init
