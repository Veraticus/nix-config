#!/usr/bin/env bash
# tmux-devspace — manage named tmux sessions with dev context metadata
#
# Commands:
#   new [--label L] [--icon I] [--name N] [name] [-- cmd...]  Create session
#   attach [--icon I] <name> [-- cmd...]                       Attach or create
#   name                                                        Print auto name
#   rename [cmd]                                                Auto-rename session
#   title-path [path]                                           Fish-style path
set -euo pipefail

die() { echo "tmux-devspace: $*" >&2; exit 64; }

# --- Helpers ---

sanitize() {
  local s="${1,,}"                          # lowercase
  s="${s//[^[:alnum:]-]/-}"                 # replace non-alnum
  s="${s##-}"; s="${s%%-}"                   # trim leading/trailing -
  s="${s//--/-}"                             # collapse --
  printf '%s' "${s:-session}"
}

label() {
  # Priority: explicit override > TMUX_LABEL_OVERRIDE > TMUX_DEVSPACE > hostname
  printf '%s' "${label_override:-${TMUX_LABEL_OVERRIDE:-${TMUX_DEVSPACE:-$(hostname -s 2>/dev/null || echo host)}}}"
}

compress_path() {
  local path="${1:-${PWD:-$(pwd)}}" prefix=""
  if [[ "$path" == "$HOME"* ]]; then
    prefix="~"; path="${path#"$HOME"}"
  fi
  path="${path#/}"
  [[ -z "$path" ]] && { printf '%s' "${prefix:-/}"; return; }

  IFS='/' read -ra parts <<< "$path"
  local n=${#parts[@]}
  if (( n > 2 )); then
    printf '%s/…/%s/%s' "$prefix" "${parts[-2]}" "${parts[-1]}"
  elif (( n == 2 )); then
    local short="${parts[0]}"; (( ${#short} > 2 )) && short="${short:0:2}"
    printf '%s/%s/%s' "$prefix" "$short" "${parts[1]}"
  else
    printf '%s/%s' "$prefix" "${parts[0]}"
  fi
}

command_name() {
  local cmd="${1:-}"
  [[ -z "$cmd" ]] && { basename "${SHELL:-zsh}"; return; }
  cmd="${cmd%%$'\n'*}"       # first line
  cmd="${cmd%% *}"           # first word
  printf '%s' "${cmd##*/}"   # strip path
}

dynamic_name() {
  printf '%s·%s·%s' "$(label)" "$(compress_path)" "$(command_name "${1:-}")"
}

set_context() {
  local session="$1" lbl="$2" auto="$3" icon="${4:-}"
  local -a vars=(
    "TMUX_DEVSPACE=$lbl"
    "TMUX_LABEL_OVERRIDE=$lbl"
    "TMUX_AUTO_NAME=$auto"
    "DEV_CONTEXT=$lbl"
    "DEV_CONTEXT_KIND=tmux"
  )
  [[ -n "$icon" ]] && vars+=("DEV_CONTEXT_ICON=$icon")
  for v in "${vars[@]}"; do
    tmux set-environment -t "$session" -g "${v%%=*}" "${v#*=}" 2>/dev/null || true
  done
  tmux set-option -t "$session" @dev_context "$lbl" 2>/dev/null || true
  tmux set-option -t "$session" @dev_context_kind "tmux" 2>/dev/null || true
  [[ -n "$icon" ]] && tmux set-option -t "$session" @dev_context_icon "$icon" 2>/dev/null || true
}

connect() {
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$1"
  else
    exec tmux attach-session -t "$1"
  fi
}

# --- Commands ---

cmd_new() {
  local label_override="" icon="" name="" cmd=()
  while (( $# )); do
    case "$1" in
      --label)  label_override="$(sanitize "$2")"; shift 2 ;;
      --label=*) label_override="$(sanitize "${1#*=}")"; shift ;;
      --icon)   icon="$2"; shift 2 ;;
      --icon=*) icon="${1#*=}"; shift ;;
      --name)   name="$(sanitize "$2")"; shift 2 ;;
      --name=*) name="$(sanitize "${1#*=}")"; shift ;;
      --)       shift; cmd=("$@"); break ;;
      -*)       cmd=("$@"); break ;;
      *)        [[ -z "$name" ]] && { name="$(sanitize "$1")"; shift; } || { cmd=("$@"); break; } ;;
    esac
  done

  local session auto
  if [[ -n "$name" ]]; then
    session="$name"; auto=0
  else
    session="$(dynamic_name "${cmd[0]:-}")"; auto=1
  fi

  tmux new-session -d -s "$session" "${cmd[@]}" 2>/dev/null || true
  set_context "$session" "${label_override:-${name:-$(label)}}" "$auto" "$icon"
  connect "$session"
}

cmd_attach() {
  local icon=""
  while (( $# )); do
    case "$1" in
      --icon)   icon="$2"; shift 2 ;;
      --icon=*) icon="${1#*=}"; shift ;;
      --)       shift; break ;;
      -*)       break ;;
      *)        break ;;
    esac
  done
  (( $# )) || die "attach requires a session name"

  local name="$1"; shift
  [[ "${1:-}" == "--" ]] && shift
  local sanitized="$(sanitize "$name")"

  # Find existing session: try raw name, then sanitized
  local session=""
  if tmux has-session -t "$name" 2>/dev/null; then
    session="$name"
  elif [[ "$sanitized" != "$name" ]] && tmux has-session -t "$sanitized" 2>/dev/null; then
    session="$sanitized"
  fi

  if [[ -n "$session" ]]; then
    # Existing session — update context and attach
    local lbl
    lbl="$(tmux show-environment -t "$session" TMUX_LABEL_OVERRIDE 2>/dev/null | cut -d= -f2- || echo "$session")"
    set_context "$session" "${lbl:-$session}" 0 "$icon"
  else
    # Create new session
    session="$sanitized"
    local -a env_opts=(
      -e "TMUX_DEVSPACE=$sanitized"
      -e "TMUX_LABEL_OVERRIDE=$sanitized"
      -e "TMUX_AUTO_NAME=0"
      -e "DEV_CONTEXT=$sanitized"
      -e "DEV_CONTEXT_KIND=tmux"
    )
    [[ -n "$icon" ]] && env_opts+=(-e "DEV_CONTEXT_ICON=$icon")
    tmux new-session -d "${env_opts[@]}" -s "$sanitized" "$@"
    set_context "$sanitized" "$sanitized" 0 "$icon"
  fi
  connect "$session"
}

cmd_name() {
  printf '%s\n' "$(dynamic_name)"
}

cmd_rename() {
  [[ -z "${TMUX:-}" ]] && return 0
  [[ "${TMUX_AUTO_NAME:-0}" == "1" ]] || return 0
  local session
  session="$(tmux display-message -p '#S' 2>/dev/null)" || return 0
  [[ -n "$session" ]] && tmux rename-session -t "$session" "$(dynamic_name "${1:-}")"
}

cmd_title_path() {
  compress_path "${1:-}"
  printf '\n'
}

# --- Dispatch ---

[[ $# -gt 0 ]] || die "usage: tmux-devspace {new|attach|name|rename|title-path} [args]"
cmd="$1"; shift
case "$cmd" in
  new)        cmd_new "$@" ;;
  attach)     cmd_attach "$@" ;;
  name)       cmd_name ;;
  rename)     cmd_rename "$@" ;;
  title-path) cmd_title_path "$@" ;;
  *)          die "unknown command: $cmd" ;;
esac
