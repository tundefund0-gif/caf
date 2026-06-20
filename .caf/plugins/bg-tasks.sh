#############################################
# CAF Plugin: Background Tasks
# Provides: bg, bg_list, bg_result, bg_cancel, bg_wait
#############################################

plugin_bg_tasks_init() {
  register_tool "bg"        "tool_bg"
  register_tool "bg_list"   "tool_bg_list"
  register_tool "bg_result" "tool_bg_result"
  register_tool "bg_cancel" "tool_bg_cancel"
  register_tool "bg_wait"   "tool_bg_wait"
  return 0
}

CAF_TASKS_DIR="${CAF_TASKS_DIR:-$HOME/.caf/tasks}"
mkdir -p "$CAF_TASKS_DIR" 2>/dev/null

_tasks_next_id() {
  local id=1
  while [ -f "$CAF_TASKS_DIR/task_$(printf '%04d' $id).meta" ]; do
    id=$((id + 1))
  done
  printf '%04d' "$id"
}

_tasks_save_meta() {
  local id="$1"
  local name="$2"
  local cmd="$3"
  local status="$4"
  local pid="${5:-}"
  local dir="${6:-$(pwd)}"

  cat > "$CAF_TASKS_DIR/task_${id}.meta" << META
TASK_ID=$id
TASK_NAME=$name
TASK_CMD=$cmd
TASK_STATUS=$status
TASK_PID=$pid
TASK_DIR=$dir
TASK_START=$(date -Iseconds)
META
}

#############################################
# Run a command in the background
#############################################
tool_bg() {
  local cmd="$1"
  local name="${2:-$cmd}"
  # Extract command from JSON if passed as such
  if echo "$cmd" | jq -e '.command' &>/dev/null 2>&1; then
    cmd=$(echo "$cmd" | jq -r '.command // empty')
    local json_name
    json_name=$(echo "$cmd" | jq -r '.description // .name // empty' 2>/dev/null)
    [ -n "$json_name" ] && name="$json_name"
  fi

  local id
  id=$(_tasks_next_id)

  _tasks_save_meta "$id" "$name" "$cmd" "running"

  # Execute in background, capture output
  (
    cd "$(pwd)" 2>/dev/null || true
    echo "[Task $id] Starting: $name"

    # Run with timeout
    if command -v timeout &>/dev/null; then
      timeout "$CAF_TIMEOUT" bash -c "$cmd" 2>&1
    else
      bash -c "$cmd" 2>&1
    fi

    local rc=$?
    echo "[Task $id] Exit code: $rc"
    echo "[Task $id] Finished at: $(date -Iseconds)"
  ) > "$CAF_TASKS_DIR/task_${id}.out" 2>&1 &

  local pid=$!
  disown "$pid" 2>/dev/null

  _tasks_save_meta "$id" "$name" "$cmd" "running" "$pid"

  echo "**Background Task #$id Started**"
  echo "- Name: $name"
  echo "- PID: $pid"
  echo "- To check: bg_result $id"
  echo "- To list: bg_list"
  return 0
}

#############################################
# List all background tasks
#############################################
tool_bg_list() {
  echo "**Background Tasks**"
  echo ""

  local found=0
  local meta_file
  for meta_file in "$CAF_TASKS_DIR"/task_*.meta; do
    [ -f "$meta_file" ] || continue
    found=1

    local id name status pid dir
    id=$(grep "^TASK_ID=" "$meta_file" | cut -d= -f2-)
    name=$(grep "^TASK_NAME=" "$meta_file" | cut -d= -f2-)
    status=$(grep "^TASK_STATUS=" "$meta_file" | cut -d= -f2-)
    pid=$(grep "^TASK_PID=" "$meta_file" | cut -d= -f2-)
    dir=$(grep "^TASK_DIR=" "$meta_file" | cut -d= -f2-)

    # Check if still running
    if [ "$status" = "running" ] && [ -n "$pid" ]; then
      if kill -0 "$pid" 2>/dev/null; then
        status="🟢 running"
      else
        status="✅ completed"
        # Update meta
        sed -i "s/^TASK_STATUS=.*/TASK_STATUS=completed/" "$meta_file"
      fi
    fi

    echo "  #$id: $name [$status]"
    echo "    Dir: $dir | Cmd: ..."
  done

  [ "$found" -eq 0 ] && echo "  No background tasks."
  return 0
}

#############################################
# Get result/output of a background task
#############################################
tool_bg_result() {
  local id="$1"
  local meta_file="$CAF_TASKS_DIR/task_${id}.meta"
  local out_file="$CAF_TASKS_DIR/task_${id}.out"

  if [ ! -f "$meta_file" ]; then
    log_error "Task #$id not found"
    echo "Task #$id does not exist."
    return 1
  fi

  local status pid
  status=$(grep "^TASK_STATUS=" "$meta_file" | cut -d= -f2-)
  pid=$(grep "^TASK_PID=" "$meta_file" | cut -d= -f2-)

  # Check if still running
  if [ "$status" = "running" ] && [ -n "$pid" ]; then
    if kill -0 "$pid" 2>/dev/null; then
      echo "**Task #$id is still running** (PID: $pid)"
    else
      status="completed"
      sed -i "s/^TASK_STATUS=.*/TASK_STATUS=completed/" "$meta_file"
    fi
  fi

  echo "**Task #$id Output**"
  echo ""

  if [ -f "$out_file" ]; then
    cat "$out_file"
  else
    echo "(no output file)"
  fi
  return 0
}

#############################################
# Cancel a background task
#############################################
tool_bg_cancel() {
  local id="$1"
  local meta_file="$CAF_TASKS_DIR/task_${id}.meta"

  if [ ! -f "$meta_file" ]; then
    log_error "Task #$id not found"
    return 1
  fi

  local pid
  pid=$(grep "^TASK_PID=" "$meta_file" | cut -d= -f2-)

  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    echo "**Task #$id cancelled** (PID: $pid)"
    sed -i "s/^TASK_STATUS=.*/TASK_STATUS=cancelled/" "$meta_file"
  else
    echo "Task #$id is not running."
  fi
  return 0
}

#############################################
# Wait for a background task to complete
#############################################
tool_bg_wait() {
  local id="$1"
  local timeout="${2:-$CAF_TIMEOUT}"
  local meta_file="$CAF_TASKS_DIR/task_${id}.meta"

  if [ ! -f "$meta_file" ]; then
    log_error "Task #$id not found"
    return 1
  fi

  local pid status
  pid=$(grep "^TASK_PID=" "$meta_file" | cut -d= -f2-)
  status=$(grep "^TASK_STATUS=" "$meta_file" | cut -d= -f2-)

  if [ "$status" != "running" ]; then
    tool_bg_result "$id"
    return 0
  fi

  if [ -z "$pid" ]; then
    echo "No PID for task #$id"
    return 1
  fi

  echo "Waiting for task #$id (PID: $pid)..."

  local waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      sed -i "s/^TASK_STATUS=.*/TASK_STATUS=completed/" "$meta_file"
      echo "Task #$id completed after ${waited}s"
      tool_bg_result "$id"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  echo "Timed out waiting for task #$id (${timeout}s)"
  return 124
}

plugin_bg_tasks_init
