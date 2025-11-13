#!/usr/bin/env bash
set -euo pipefail

separator='·'
truncation_length=2
fish_component_length=2
truncation_symbol='…/'
label_override=''
new_icon=''

usage() {
  cat <<'USAGE' >&2
Usage: tmux-devspace <command> [args]
  new [--label slug] [name] [-- command ...]
                             Create a tmux session (auto name if NAME omitted)
  attach <name> [command ...] Attach to a session, creating it if needed
  name                        Print a generated session name
  rename [command]            Recompute and rename the current session (inside tmux)
USAGE
  exit 64
}

ensure_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux-devspace: tmux is not available in PATH" >&2
    exit 127
  fi
}

sanitize_label() {
  local input="$1"
  input=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')
  input=$(printf '%s' "$input" | tr -c '[:alnum:]-' '-')
  input=$(printf '%s' "$input" | sed 's/^-*//;s/-*$//;s/--*/-/g')
  if [ -z "$input" ]; then
    input="session"
  fi
  printf '%s' "$input"
}

effective_label() {
  if [ -n "$label_override" ]; then
    printf '%s' "$label_override"
  elif [ -n "${TMUX_LABEL_OVERRIDE:-}" ]; then
    printf '%s' "$TMUX_LABEL_OVERRIDE"
  elif [ -n "${TMUX_DEVSPACE:-}" ]; then
    printf '%s' "$TMUX_DEVSPACE"
  else
    local host
    host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "host")
    printf '%s' "$host"
  fi
}

host_segment() {
  printf '%s' "$(effective_label)"
}

strip_path() {
  local path home prefix
  path=${PWD:-$(pwd)}
  home=${HOME:-}
  prefix=""

  if [ -n "$home" ] && [ "${path#"${home}"}" != "$path" ]; then
    prefix="~"
    path="${path#$home}"
  fi

  path="${path#/}"
  IFS='/' read -r -a raw_parts <<< "$path"
  local parts=()
  for seg in "${raw_parts[@]}"; do
    if [ -n "$seg" ]; then
      parts+=( "$seg" )
    fi
  done

  if [ ${#parts[@]} -eq 0 ]; then
    if [ -n "$prefix" ]; then
      printf '%s' "$prefix"
    else
      printf '/'
    fi
    return
  fi

  local truncated=0
  local formatted=()
  if [ ${#parts[@]} -gt $truncation_length ]; then
    truncated=1
    parts=( "${parts[@]: -$truncation_length}" )
    formatted=( "${parts[@]}" )
  else
    local last_index=$(( ${#parts[@]} - 1 ))
    local idx=0
    for seg in "${parts[@]}"; do
      if [ $idx -lt $last_index ]; then
        if [ ${#seg} -gt $fish_component_length ]; then
          formatted+=( "${seg:0:$fish_component_length}" )
        else
          formatted+=( "$seg" )
        fi
      else
        formatted+=( "$seg" )
      fi
      idx=$(( idx + 1 ))
    done
  fi

  local combined=""
  for seg in "${formatted[@]}"; do
    if [ -n "$combined" ]; then
      combined="${combined}/${seg}"
    else
      combined="$seg"
    fi
  done

  local indicator=""
  if [ $truncated -eq 1 ]; then
    indicator=$truncation_symbol
  fi

  if [ -n "$prefix" ]; then
    if [ -n "$combined" ]; then
      printf '%s/%s%s' "$prefix" "$indicator" "$combined"
    else
      printf '%s' "$prefix"
    fi
  else
    if [ -n "$combined" ]; then
      printf '/%s%s' "$indicator" "$combined"
    else
      printf '/'
    fi
  fi
}

command_segment() {
  local input="${1:-}"
  if [ -z "$input" ]; then
    printf '%s' "$(basename "${SHELL:-zsh}")"
    return
  fi

  input="${input%%$'\n'*}"
  local first="${input%% *}"
  if [ -z "$first" ]; then
    first="$input"
  fi
  first=${first##*/}
  if [ -z "$first" ]; then
    first="$input"
  fi
  printf '%s' "$first"
}

build_dynamic_name() {
  local cmd_hint="${1:-}"
  printf '%s%s%s%s%s' "$(host_segment)" "$separator" "$(strip_path)" "$separator" "$(command_segment "$cmd_hint")"
}

set_session_context() {
  local session="$1"
  local env_label="$2"
  local auto_flag="$3"
  local context_icon="$4"

  tmux set-environment -t "$session" -g TMUX_DEVSPACE "$env_label" >/dev/null 2>&1 || true
  tmux set-environment -t "$session" -g TMUX_LABEL_OVERRIDE "$env_label" >/dev/null 2>&1 || true
  tmux set-environment -t "$session" -g TMUX_AUTO_NAME "$auto_flag" >/dev/null 2>&1 || true

  tmux set-environment -t "$session" -g DEV_CONTEXT "$env_label" >/dev/null 2>&1 || true
  tmux set-environment -t "$session" -g DEV_CONTEXT_KIND "tmux" >/dev/null 2>&1 || true

  if [ -n "$context_icon" ]; then
    tmux set-environment -t "$session" -g DEV_CONTEXT_ICON "$context_icon" >/dev/null 2>&1 || true
  fi
}

attach_or_switch() {
  local session="$1"
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$session"
  else
    exec tmux attach-session -t "$session"
  fi
}

tmux_new_session() {
  local session="$1"; shift
  local env_label="$1"; shift
  local auto_flag="$1"; shift
  local context_icon="$1"; shift
  # Always create the session detached so we can reliably set
  # its environment before attaching or switching clients.
  if [ $# -gt 0 ]; then
    tmux new-session -d -s "$session" "$@"
  else
    tmux new-session -d -s "$session"
  fi
  set_session_context "$session" "$env_label" "$auto_flag" "$context_icon"
  attach_or_switch "$session"
}

session_label_or_default() {
  local session="$1"
  local value
  value=$(tmux show-environment -t "$session" TMUX_LABEL_OVERRIDE 2>/dev/null | sed 's/^[^=]*=//')
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$session"
  fi
}

current_session() {
  tmux display-message -p '#S' 2>/dev/null || true
}

parse_new_args() {
  label_override=''
  new_icon=''
  new_name=''
  auto_hint='0'
  new_cmd_hint=''
  new_cmd=()
  local parsing=1

  while [ $parsing -eq 1 ] && [ $# -gt 0 ]; do
    case "$1" in
      --label)
        [ $# -ge 2 ] || { echo "tmux-devspace: --label requires an argument" >&2; exit 64; }
        label_override=$(sanitize_label "$2")
        shift 2
        ;;
      --label=*)
        label_override=$(sanitize_label "${1#--label=}")
        shift
        ;;
      --icon)
        [ $# -ge 2 ] || { echo "tmux-devspace: --icon requires an argument" >&2; exit 64; }
        new_icon="$2"
        shift 2
        ;;
      --icon=*)
        new_icon="${1#--icon=}"
        shift
        ;;
      --name)
        [ $# -ge 2 ] || { echo "tmux-devspace: --name requires an argument" >&2; exit 64; }
        new_name=$(sanitize_label "$2")
        shift 2
        ;;
      --name=*)
        new_name=$(sanitize_label "${1#--name=}")
        shift
        ;;
      --)
        shift
        parsing=0
        ;;
      *)
        parsing=0
        ;;
    esac
  done

  if [ -z "$new_name" ] && [ $# -gt 0 ] && [ "${1:-}" != "--" ]; then
    new_name=$(sanitize_label "$1")
    shift
  fi

  if [ $# -gt 0 ] && [ "${1:-}" = "--" ]; then
    shift
  fi

  if [ $# -gt 0 ]; then
    new_cmd=( "$@" )
    new_cmd_hint="${new_cmd[0]}"
  else
    new_cmd_hint=""
  fi
}

cmd_new() {
  ensure_tmux
  parse_new_args "$@"

  local session env_label auto_flag
  if [ -n "$new_name" ]; then
    session="$new_name"
    env_label="${label_override:-$session}"
    auto_flag='0'
  else
    env_label="$(effective_label)"
    session="$(build_dynamic_name "$new_cmd_hint")"
    auto_flag='1'
  fi

  tmux_new_session "$session" "$env_label" "$auto_flag" "$new_icon" "${new_cmd[@]}"
}

cmd_attach() {
  ensure_tmux

  if [ $# -lt 1 ]; then
    echo "tmux-devspace attach [--icon icon] <name> [command ...]" >&2
    exit 64
  fi

  local icon_override=''
  local parsing=1
  while [ $parsing -eq 1 ] && [ $# -gt 0 ]; do
    case "$1" in
      --icon)
        [ $# -ge 2 ] || { echo "tmux-devspace: --icon requires an argument" >&2; exit 64; }
        icon_override="$2"
        shift 2
        ;;
      --icon=*)
        icon_override="${1#--icon=}"
        shift
        ;;
      --)
        parsing=0
        shift
        ;;
      -*)
        parsing=0
        ;;
      *)
        parsing=0
        ;;
    esac
  done

  if [ $# -lt 1 ]; then
    echo "tmux-devspace attach [--icon icon] <name> [command ...]" >&2
    exit 64
  fi

  local requested_session="$1"
  shift || true
  local sanitized="$(sanitize_label "$requested_session")"
  local session="$requested_session"
  if ! tmux has-session -t "$session" >/dev/null 2>&1 && [ "$sanitized" != "$session" ]; then
    if tmux has-session -t "$sanitized" >/dev/null 2>&1; then
      session="$sanitized"
    fi
  fi
  if [ $# -gt 0 ] && [ "${1:-}" = "--" ]; then
    shift
  fi

  local -a cmd=()
  if [ $# -gt 0 ]; then
    cmd=( "$@" )
  fi

  if tmux has-session -t "$session" >/dev/null 2>&1; then
    local label
    label=$(session_label_or_default "$session")
    set_session_context "$session" "$label" 0 "$icon_override"
  else
    local -a env_opts=(
      "-e" "TMUX_DEVSPACE=$sanitized"
      "-e" "TMUX_LABEL_OVERRIDE=$sanitized"
      "-e" "TMUX_AUTO_NAME=0"
      "-e" "DEV_CONTEXT=$sanitized"
      "-e" "DEV_CONTEXT_KIND=tmux"
    )
    if [ -n "$icon_override" ]; then
      env_opts+=( "-e" "DEV_CONTEXT_ICON=$icon_override" )
    fi
    if [ ${#cmd[@]} -gt 0 ]; then
      tmux new-session -d "${env_opts[@]}" -s "$sanitized" "${cmd[@]}"
    else
      tmux new-session -d "${env_opts[@]}" -s "$sanitized"
    fi
    set_session_context "$sanitized" "$sanitized" 0 "$icon_override"
    session="$sanitized"
  fi
  attach_or_switch "$session"
}

cmd_name() {
  printf '%s\n' "$(build_dynamic_name)"
}

cmd_rename() {
  if [ -z "${TMUX:-}" ]; then
    return 0
  fi
  if [ "${TMUX_AUTO_NAME:-0}" != "1" ]; then
    return 0
  fi
  ensure_tmux
  local session
  session=$(current_session)
  if [ -z "$session" ]; then
    return 0
  fi
  local new_name
  new_name=$(build_dynamic_name "${1:-}")
  tmux rename-session -t "$session" "$new_name"
}

command="${1:-}"
if [ -z "$command" ]; then
  usage
fi

shift || true

case "$command" in
  new)
    cmd_new "$@"
    ;;
  attach)
    cmd_attach "$@"
    ;;
  name)
    cmd_name
    ;;
  rename)
    cmd_rename "$@"
    ;;
  *)
    usage
    ;;
esac
