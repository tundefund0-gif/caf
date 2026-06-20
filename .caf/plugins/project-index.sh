#############################################
# CAF Plugin: Project Index
# VSCode-like workspace indexing for fast navigation
# Provides: index_project, search_symbols, find_file, index_status, watch_project
#############################################

plugin_project_index_init() {
  register_tool "index_project"  "tool_index_project"
  register_tool "search_symbols" "tool_search_symbols"
  register_tool "find_file"      "tool_find_file"
  register_tool "index_status"   "tool_index_status"
  register_tool "watch_project"  "tool_watch_project"
  return 0
}

#############################################
# Build/refresh project index
#############################################
tool_index_project() {
  local dir="${1:-$(pwd)}"
  local force="${2:-false}"

  log_info "Indexing project: $dir"

  local index_file="$CAF_INDEX_DIR/$(echo "$dir" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$dir" | sha256sum | cut -d' ' -f1).idx"
  mkdir -p "$(dirname "$index_file")" 2>/dev/null

  # Build ignore patterns
  local ignore_patterns=""
  local d
  for d in $CAF_IGNORE_DIRS; do
    ignore_patterns="$ignore_patterns -not -path '*/$d/*'"
  done

  # --- File index ---
  log_info "Scanning files..."
  eval "find \"$dir\" -type f $ignore_patterns 2>/dev/null" > "${index_file}.files"

  local file_count
  file_count=$(wc -l < "${index_file}.files")
  log_info "Found $file_count files"

  # --- Symbol index (function/class definitions) ---
  log_info "Building symbol index..."
  > "${index_file}.symbols"

  local f
  while IFS= read -r f; do
    case "$f" in
      *.sh|*.bash|*.zsh)
        grep -n "^[[:space:]]*function\|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*()" "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
      *.py)
        grep -n "^class\|^def " "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
      *.js|*.ts|*.jsx|*.tsx)
        grep -n "^[[:space:]]*function\|^[[:space:]]*class\|^[[:space:]]*export\|^[[:space:]]*const.*=>\|^[[:space:]]*async\|^[[:space:]]*interface\|^[[:space:]]*type " "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
      *.go)
        grep -n "^func\|^type\|^struct\|^interface\|^var\|^const " "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
      *.rs)
        grep -n "^fn\|^struct\|^enum\|^trait\|^impl\|^mod\|^pub\|^type\|^const\|^macro_rules!" "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
      *.c|*.cpp|*.h|*.hpp)
        grep -n "^[[:space:]]*int\|^[[:space:]]*void\|^[[:space:]]*char\|^[[:space:]]*struct\|^[[:space:]]*class\|^[[:space:]]*namespace\|^[[:space:]]*template" "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
      *.java)
        grep -n "^[[:space:]]*class\|^[[:space:]]*interface\|^[[:space:]]*enum\|^[[:space:]]*public\|^[[:space:]]*private\|^[[:space:]]*protected" "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
      *.md)
        grep -n "^##\|^#\|^###" "$f" 2>/dev/null | \
          while IFS=: read -r line sym; do
            echo "$sym|$line|$f" >> "${index_file}.symbols"
          done
        ;;
    esac
  done < "${index_file}.files"

  local sym_count
  sym_count=$(wc -l < "${index_file}.symbols")
  log_info "Found $sym_count symbols"

  # --- Extension stats ---
  log_info "Counting file types..."
  awk -F. '{if(NF>1) ext=$NF; else ext="(no ext)"; count[ext]++} END{for(e in count) print e, count[e]}' \
    "${index_file}.files" | sort -k2 -rn > "${index_file}.exts"

  # Save metadata
  cat > "${index_file}.meta" << META
dir=$dir
files=$file_count
symbols=$sym_count
date=$(date -Iseconds)
META

  # Link latest
  ln -sf "$index_file" "$CAF_INDEX_DIR/current.idx" 2>/dev/null

  log_info "Index complete: $file_count files, $sym_count symbols"

  echo "**Project Index Report**"
  echo "- Files indexed: $file_count"
  echo "- Symbols found: $sym_count"
  echo ""
  echo "Top file types:"
  head -10 "${index_file}.exts" | while read -r ext count; do
    echo "  .$ext: $count files"
  done
  return 0
}

#############################################
# Search for symbols (functions, classes, etc.)
#############################################
tool_search_symbols() {
  local query="$1"
  local dir="${2:-$(pwd)}"

  local index_file="$CAF_INDEX_DIR/$(echo "$dir" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$dir" | sha256sum | cut -d' ' -f1).idx"

  if [ ! -f "${index_file}.symbols" ]; then
    log_warn "No index found for $dir. Run index_project first."
    echo "Index not found. Use index_project to build it."
    return 1
  fi

  log_info "Searching symbols for: $query"
  grep -i "$query" "${index_file}.symbols" 2>/dev/null | head -30 | \
    while IFS='|' read -r sym line file; do
      local rel_path
      rel_path=$(echo "$file" | sed "s|$dir/||")
      echo "  $sym ($rel_path:$line)"
    done

  echo ""
  echo "Found $(grep -ci "$query" "${index_file}.symbols" 2>/dev/null || echo 0) matches"
  return 0
}

#############################################
# Quick file finder
#############################################
tool_find_file() {
  local pattern="$1"
  local dir="${2:-$(pwd)}"

  local index_file="$CAF_INDEX_DIR/$(echo "$dir" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$dir" | sha256sum | cut -d' ' -f1).idx"

  if [ -f "${index_file}.files" ]; then
    log_info "Searching index for: $pattern"
    grep -i "$pattern" "${index_file}.files" 2>/dev/null | head -30 | \
      while IFS= read -r f; do
        echo "  $f"
      done
  else
    log_info "No index, using find for: $pattern"
    eval "find \"$dir\" -type f -name '*${pattern}*' $ignore_patterns 2>/dev/null" | head -30 | \
      while IFS= read -r f; do
        echo "  $f"
      done
  fi

  echo ""
  echo "Done."
  return 0
}

#############################################
# Index status
#############################################
tool_index_status() {
  local dir="${1:-$(pwd)}"
  local index_file="$CAF_INDEX_DIR/$(echo "$dir" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$dir" | sha256sum | cut -d' ' -f1).idx"

  if [ -f "${index_file}.meta" ]; then
    echo "**Project Index Status**"
    cat "${index_file}.meta"
    echo ""
    echo "Top file types:"
    head -5 "${index_file}.exts" 2>/dev/null
  else
    echo "No index exists for $dir. Run index_project to build one."
  fi
  return 0
}

#############################################
# Watch project for changes (simple poll-based)
#############################################
tool_watch_project() {
  local dir="${1:-$(pwd)}"
  local duration="${2:-60}"  # seconds to watch
  local interval="${3:-5}"   # poll interval

  log_info "Watching $dir for changes (${duration}s, interval ${interval}s)"

  local -A old_mtimes
  local f
  while IFS= read -r f; do
    old_mtimes["$f"]=$(stat -c%Y "$f" 2>/dev/null)
  done < <(find "$dir" -type f 2>/dev/null)

  local elapsed=0
  local changed=0

  while [ "$elapsed" -lt "$duration" ]; do
    sleep "$interval"
    elapsed=$((elapsed + interval))

    while IFS= read -r f; do
      local new_mtime
      new_mtime=$(stat -c%Y "$f" 2>/dev/null)
      if [ "${old_mtimes[$f]}" != "$new_mtime" ] && [ -n "$new_mtime" ]; then
        echo "[CHANGED] $f"
        old_mtimes["$f"]="$new_mtime"
        changed=$((changed + 1))
      fi
    done < <(find "$dir" -type f 2>/dev/null)
  done

  echo ""
  echo "Watched for ${duration}s. $changed files changed."
  return 0
}

plugin_project_index_init
