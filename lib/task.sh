#!/usr/bin/env bash
# lib/task.sh — Lark Project task management (equivalent to openclaw approvals)

cmd_task() {
  local action="${1:-list}"; shift || true
  case "$action" in
    list)   _task_list "$@" ;;
    create) _task_create "$@" ;;
    done)   _task_done "$@" ;;
    help|--help|-h) _task_help ;;
    *)      _task_help; return 1 ;;
  esac
}

_task_help() {
  cat <<EOF

Usage: larc task <list|create|done>

  larc task list
  larc task create --title "Q2 budget review" [--due 2026-04-20]
  larc task done <task_guid>

EOF
}

_task_list() {
  log_head "Task list (Lark Project)"
  lark-cli task +get-my-tasks 2>/dev/null || {
    log_warn "Failed to fetch tasks"
  }
}

_task_create() {
  local title="" due=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title|--summary) title="$2"; shift 2 ;;
      --due) due="$2"; shift 2 ;;
      *)
        if [[ -z "$title" ]]; then
          title="$1"
        elif [[ -z "$due" ]]; then
          due="$1"
        else
          log_warn "Unknown option: $1"
        fi
        shift
        ;;
    esac
  done
  [[ -z "$title" ]] && { read -r -p "Task name: " title; }
  log_head "Create task: $title"
  local due_value
  due_value=$(_task_due_value "${due:-+1 day}")
  lark-cli task +create \
    --summary "$title" \
    --due "$due_value" \
    2>/dev/null && log_ok "Task created" || { log_error "Task create failed (title: '$title')"; return 1; }
}

_task_done() {
  local task_id="${1:-}"
  [[ -z "$task_id" ]] && { log_error "Please specify a task_id"; return 1; }
  log_head "Complete task: $task_id"
  lark-cli task +complete \
    --task-id "$task_id" \
    2>/dev/null && log_ok "Completed" || { log_error "Update failed for task_id: $task_id"; return 1; }
}

_task_due_value() {
  local due_expr="$1"

  case "$due_expr" in
    "+1 day" | "+1 days") echo "+1d" ;;
    "+2 day" | "+2 days") echo "+2d" ;;
    "+3 day" | "+3 days") echo "+3d" ;;
    "") echo "+1d" ;;
    *) echo "$due_expr" ;;
  esac
}
