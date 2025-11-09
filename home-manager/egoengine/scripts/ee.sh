#!/usr/bin/env bash
set -euo pipefail

script_name=${0##*/}

vault=${EE_VAULT:-egoengine}
service_item=${EE_SERVICE_ITEM:-service-account}
work_item=${EE_WORK_ITEM:-work}
personal_item=${EE_PERSONAL_ITEM:-personal}
sync_manifest_path_default="$HOME/.local/state/ee/synced-files"
sync_manifest_path=${WORKSPACE_SECRET_MANIFEST:-${EE_SYNC_MANIFEST_PATH:-$sync_manifest_path_default}}
export WORKSPACE_SECRET_MANIFEST="$sync_manifest_path"
export EE_SYNC_MANIFEST_PATH="$sync_manifest_path"

if [ -z "${WORKSPACE_SECRET_CLEAN_CMD:-}" ]; then
  export WORKSPACE_SECRET_CLEAN_CMD='rm -rf "$HOME/.aws"'
fi

usage() {
  cat <<'EOF'
Usage:
  ee [--verbose] <command>
  ee secret <path>         Upload or update a workspace file in 1Password
  ee sync [--quiet]        Mirror 1Password document items into $HOME
  ee work|w [coder args]   Run coder with work environment credentials
  ee personal|p [args]     Run coder with personal environment credentials
                           (leading 'coder' argument is optional)
  ee personal|p go <dir> [workspace]
                           Ensure/create a workspace for the repo at <dir> and connect via SSH

Environment:
  EE_VAULT           Override the 1Password vault name (default: egoengine)
  EE_SERVICE_ITEM    Name of the service account note (default: service-account)
  EE_WORK_ITEM       Name of the work env note (default: work)
  EE_PERSONAL_ITEM   Name of the personal env note (default: personal)
  EE_CACHE_REPO      Optional cache registry (e.g. ghcr.io/Veraticus/envbuilder-cache)
  EE_CACHE_REPO_DOCKER_CONFIG_PATH
                     Path on the Coder host/container to a docker config.json with registry creds
  EE_VERBOSE         Set to 1 to enable verbose logging (or pass --verbose)
EOF
}

die() {
  printf '%s: %s\n' "$script_name" "$1" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "required command '$1' not found in PATH"
  fi
}

log() {
  if [ -n "${EE_VERBOSE:-}" ]; then
    printf '[ee] %s\n' "$*" >&2
  fi
}

sanitize_workspace_name() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

normalize_repo_url() {
  local remote=$1
  case "$remote" in
  git@*:*)
    local tmp=${remote#git@}
    local host=${tmp%%:*}
    local path=${tmp#*:}
    path=${path%.git}
    printf 'https://%s/%s\n' "$host" "$path"
    ;;
  ssh://git@*)
    local without=${remote#ssh://git@}
    local host=${without%%/*}
    local path=${without#*/}
    path=${path%.git}
    printf 'https://%s/%s\n' "$host" "$path"
    ;;
  https://* | http://*)
    printf '%s\n' "${remote%.git}"
    ;;
  *)
    printf '%s\n' "${remote%.git}"
    ;;
  esac
}

record_exported_var() {
  local key=$1
  case " $EE_EXPORTED_VARS " in
  *" $key "*) ;;
  *) EE_EXPORTED_VARS="$EE_EXPORTED_VARS $key" ;;
  esac
}

extract_repo_slug() {
  local url=$1
  case "$url" in
  https://* | http://*)
    url=${url#*://*/}
    ;;
  esac
  url=${url%.git}
  printf '%s\n' "$url"
}

resolve_relative_path() {
  local input=$1
  local abs dir base

  case "$input" in
  ~) abs=$HOME ;;
  ~/*) abs=$HOME/${input#~/} ;;
  /*) abs=$input ;;
  *) abs=$PWD/$input ;;
  esac

  dir=$(dirname -- "$abs")
  base=$(basename -- "$abs")

  if ! dir=$(cd "$dir" 2>/dev/null && pwd -P); then
    die "unable to resolve path '$input'"
  fi

  abs=$dir/$base

  if [ ! -f "$abs" ]; then
    die "path '$input' does not exist or is not a regular file"
  fi

  case "$abs" in
  "$HOME")
    die "path '$input' must reside within $HOME"
    ;;
  "$HOME"/*)
    printf '%s\n' "${abs#"$HOME"/}"
    ;;
  *)
    die "path '$input' must reside within $HOME"
    ;;
  esac
}

record_synced_file() {
  local rel_path=$1
  local manifest_dir

  manifest_dir=$(dirname -- "$sync_manifest_path")
  mkdir -p "$manifest_dir"

  if [ -f "$sync_manifest_path" ] && grep -Fxq -- "$rel_path" "$sync_manifest_path"; then
    return 0
  fi

  printf '%s\n' "$rel_path" >>"$sync_manifest_path"
}

update_secret() {
  require_cmd op

  local relative_path
  relative_path=$(resolve_relative_path "$1")
  local abs_path=$HOME/$relative_path
  local item_path=home/$relative_path

  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' RETURN

  if op document get "op://$vault/$item_path" >"$tmp" 2>/dev/null; then
    if cmp -s "$abs_path" "$tmp"; then
      printf "No changes for %s\n" "$item_path"
      trap - RETURN
      rm -f "$tmp"
      return 0
    fi
    op document edit "op://$vault/$item_path" --file "$abs_path" >/dev/null
    printf "Updated %s in vault %s\n" "$item_path" "$vault"
  else
    op document create --vault "$vault" --title "$item_path" "$abs_path" >/dev/null
    printf "Created %s in vault %s\n" "$item_path" "$vault"
  fi

  trap - RETURN
  rm -f "$tmp"
}

sync_documents() {
  require_cmd op
  log "sync_documents: starting (args: $*)"

  local quiet=0
  local dry_run=0
  local target_vault=$vault

  while [ "$#" -gt 0 ]; do
    case "$1" in
    --quiet | -q)
      quiet=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    --vault)
      shift || die "--vault requires an argument"
      target_vault=$1
      ;;
    *)
      die "unknown option '$1' for sync"
      ;;
    esac
    shift
  done

  if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    log "sync_documents: OP_SERVICE_ACCOUNT_TOKEN unset; skipping"
    if [ "$quiet" -ne 1 ]; then
      printf '%s\n' "OP_SERVICE_ACCOUNT_TOKEN not set; skipping document sync" >&2
    fi
    return 0
  fi

  log "sync_documents: listing documents from vault '$target_vault'"
  local list_output
  if ! list_output=$(op item list --vault "$target_vault" --categories document --format json 2>/dev/null); then
    if [ "$quiet" -ne 1 ]; then
      printf '%s: unable to list documents in vault %s\n' "$script_name" "$target_vault" >&2
    fi
    return 1
  fi

  local titles
  if command -v jq >/dev/null 2>&1; then
    if ! titles=$(printf '%s' "$list_output" | jq -r '.[]?.title // empty'); then
      [ "$quiet" -ne 1 ] && printf '%s\n' "Failed to parse 1Password document list (jq)" >&2
      return 1
    fi
  else
    if ! titles=$(printf '%s' "$list_output" | python3 -c 'import json, sys
items = json.load(sys.stdin)
for item in items or []:
    title = item.get("title")
    if title:
        print(title)
' 2>/dev/null); then
      [ "$quiet" -ne 1 ] && printf '%s\n' "Failed to parse 1Password document list (python3)" >&2
      return 1
    fi
  fi

  umask 077

  while IFS= read -r title; do
    [ -z "$title" ] && continue
    case "$title" in
    personal | work | service-account)
      continue
      ;;
    esac

    local rel=$title
    if [ "${rel#home/}" != "$rel" ]; then
      rel=${rel#home/}
    fi
    rel=${rel#/}

    if [ -z "$rel" ]; then
      continue
    fi

    case "$rel" in
    *..*)
      [ "$quiet" -ne 1 ] && printf '%s: skipping unsafe document title %s\n' "$script_name" "$title" >&2
      continue
      ;;
    esac

    local dest="$HOME/$rel"
    local dest_dir
    dest_dir=$(dirname -- "$dest") || continue

    if [ "$dry_run" -eq 1 ]; then
      [ "$quiet" -ne 1 ] && printf 'Would sync %s -> %s\n' "$title" "$dest"
      continue
    fi

    mkdir -p "$dest_dir"

    local tmp_file
    tmp_file=$(mktemp)
    if op document get "op://$target_vault/$title" >"$tmp_file" 2>/dev/null; then
      if [ -f "$dest" ] && cmp -s "$dest" "$tmp_file"; then
        rm -f "$tmp_file"
        record_synced_file "$rel"
        continue
      fi

      mv "$tmp_file" "$dest"
      chmod 600 "$dest"
      record_synced_file "$rel"
      [ "$quiet" -ne 1 ] && printf 'Synced %s -> %s\n' "$title" "$dest"
    else
      [ "$quiet" -ne 1 ] && printf '%s: failed to fetch document %s\n' "$script_name" "$title" >&2
      rm -f "$tmp_file"
    fi
  done <<EOF
$titles
EOF

  record_synced_file ".aws"
  log "sync_documents: completed"
}

fetch_note() {
  local item=$1
  op read "op://$vault/$item/notesPlain" 2>/dev/null
}

load_coder_env() {
  require_cmd op
  require_cmd coder

  local env_name=$1
  log "load_coder_env: loading environment '$env_name'"
  local env_item
  case "$env_name" in
  work | w) env_item=$work_item ;;
  personal | p) env_item=$personal_item ;;
  *)
    die "unknown environment '$env_name'"
    ;;
  esac

  local service_content env_content
  if ! service_content=$(fetch_note "$service_item"); then
    die "failed to read service account item '$service_item' in vault '$vault'"
  fi
  if ! env_content=$(fetch_note "$env_item"); then
    die "failed to read environment item '$env_item' in vault '$vault'"
  fi

  EE_EXPORTED_VARS=""
  local have_url=0
  local have_token=0

  if [ -n "${service_content//[[:space:]]/}" ]; then
    service_content=$(printf '%s\n' "$service_content" | sed -e 's/\r//g' -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')
    if [ -n "$service_content" ]; then
      export OP_SERVICE_ACCOUNT_TOKEN="$service_content"
      record_exported_var OP_SERVICE_ACCOUNT_TOKEN
    fi
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    '' | \#*)
      continue
      ;;
    esac
    case "$line" in
    *=*)
      key=${line%%=*}
      value=${line#*=}
      ;;
    *)
      die "invalid line in 1Password item '$env_item': $line"
      ;;
    esac

    export "$key=$value"
    record_exported_var "$key"

    case "$key" in
    CODER_URL) have_url=1 ;;
    CODER_SESSION_TOKEN) have_token=1 ;;
    esac
  done <<EOF
$env_content
EOF

  if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -z "${EE_SYNCED:-}" ]; then
    log "load_coder_env: syncing documents via 1Password"
    sync_documents --quiet || true
    export EE_SYNCED=1
    record_exported_var EE_SYNCED
  fi

  if [ "$have_url" -eq 0 ]; then
    die "CODER_URL missing from environment item '$env_item'"
  fi
  if [ "$have_token" -eq 0 ]; then
    die "CODER_SESSION_TOKEN missing from environment item '$env_item'"
  fi
  log "load_coder_env: finished loading environment '$env_name'"
}

cleanup_coder_env() {
  if [ -n "${EE_EXPORTED_VARS:-}" ]; then
    for key in $EE_EXPORTED_VARS; do
      unset "$key"
    done
  fi
  unset EE_EXPORTED_VARS
}

run_coder_env() {
  local env_name=$1
  shift || true

  load_coder_env "$env_name"

  local args=("$@")
  if [ "${#args[@]}" -gt 0 ] && [ "${args[0]}" = coder ]; then
    args=("${args[@]:1}")
  fi

  set +e
  if [ "${#args[@]}" -gt 0 ]; then
    coder "${args[@]}"
  else
    coder
  fi
  local status=$?
  set -e

  cleanup_coder_env
  return "$status"
}

workspace_go() {
  local target_dir=${1:-$PWD}
  local override_name=${2:-}
  log "workspace_go: target_dir=$target_dir override_name=$override_name"
  local fallback_image="${EE_FALLBACK_IMAGE:-ghcr.io/veraticus/nix-config/egoengine:latest}"
  local devcontainer_builder="${EE_DEVCONTAINER_BUILDER:-ghcr.io/coder/envbuilder:latest}"
  local cache_repo="${EE_CACHE_REPO:-ghcr.io/Veraticus/envbuilder-cache}"
  local cache_repo_config="${EE_CACHE_REPO_DOCKER_CONFIG_PATH:-/var/lib/coder/ghcr-cache/config.json}"

  if [ -z "$cache_repo_config" ]; then
    log "workspace_go: cache repo config path not provided; skipping cache repo parameter"
    cache_repo=""
  fi

  load_coder_env personal
  log "workspace_go: coder environment loaded"
  require_cmd coder
  require_cmd git
  require_cmd python3

  local abs_dir
  if ! abs_dir=$(cd "$target_dir" 2>/dev/null && pwd -P); then
    die "unable to resolve directory '$target_dir'"
  fi

  local repo_root
  if ! repo_root=$(git -C "$abs_dir" rev-parse --show-toplevel 2>/dev/null); then
    die "directory '$abs_dir' is not inside a git repository"
  fi

  local repo_remote
  repo_remote=$(git -C "$abs_dir" remote get-url origin 2>/dev/null || true)
  local repo_url=""
  local repo_slug=""

  if [ -n "$repo_remote" ]; then
    repo_url=$(normalize_repo_url "$repo_remote")
    repo_slug=$(extract_repo_slug "$repo_url")
  else
    die "repository at '$abs_dir' does not have an 'origin' remote"
  fi
  log "workspace_go: repo_url=$repo_url slug=$repo_slug"

  local default_name
  default_name=$(sanitize_workspace_name "$repo_slug")
  if [ -z "$default_name" ]; then
    default_name=$(sanitize_workspace_name "$(basename "$repo_root")")
  fi

  local workspace_name
  if [ -n "$override_name" ]; then
    workspace_name=$(sanitize_workspace_name "$override_name")
    if [ -z "$workspace_name" ]; then
      die "invalid workspace name '$override_name'"
    fi
  else
    workspace_name=$default_name
  fi

  if [ -z "$workspace_name" ]; then
    die "unable to determine workspace name"
  fi
  log "workspace_go: workspace name resolved to $workspace_name"

  printf 'Workspace: %s\n' "$workspace_name"
  printf 'Repository: %s\n' "$repo_url"

  log "workspace_go: querying coder for existing workspace"
  local workspace_json
  workspace_json=$(coder list --output json --search "workspace:$workspace_name owner:me" 2>/dev/null || true)

  local workspace_exists=0
  local workspace_outdated="false"

  if [ -n "$workspace_json" ] && [ "$workspace_json" != "[]" ]; then
    local parsed
    workspace_outdated=$(
      printf '%s' "$workspace_json" | python3 - <<'PY'
import sys, json
data = json.load(sys.stdin)
if data:
    w = data[0]
    print("true" if w.get("outdated") else "false")
PY
    ) || workspace_outdated="false"

    if [ -n "$workspace_outdated" ]; then
      workspace_exists=1
    fi
  fi
  log "workspace_go: workspace_exists=$workspace_exists workspace_outdated=$workspace_outdated"

  if [ "$workspace_exists" -eq 0 ]; then
    printf 'Creating workspace %s...\n' "$workspace_name"
    log "workspace_go: invoking coder create for $workspace_name"
    local -a create_args=(
      "$workspace_name"
      --template docker-envbuilder
      --parameter "repo=$repo_url"
      --parameter "fallback_image=$fallback_image"
      --parameter "devcontainer_builder=$devcontainer_builder"
    )
    if [ -n "$cache_repo" ]; then
      log "workspace_go: passing cache repo parameters"
      create_args+=(
        --parameter "cache_repo=$cache_repo"
        --parameter "cache_repo_docker_config_path=$cache_repo_config"
      )
    else
      log "workspace_go: cache repo parameters not set"
    fi
    create_args+=(--yes)
    coder create "${create_args[@]}" || return 1
  else
    if [ "$workspace_outdated" = "true" ]; then
      printf 'Updating workspace %s...\n' "$workspace_name"
      log "workspace_go: workspace outdated, running coder update"
      coder update "$workspace_name" || return 1
    fi
  fi

  printf 'Starting workspace %s...\n' "$workspace_name"
  log "workspace_go: starting workspace via coder start"
  coder start -y "$workspace_name" >/dev/null || return 1

  printf 'Connecting to %s...\n' "$workspace_name"
  log "workspace_go: connecting via coder ssh"
  coder ssh "$workspace_name"

  cleanup_coder_env
  log "workspace_go: completed"
}

main() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --verbose|-v)
        EE_VERBOSE=1
        export EE_VERBOSE
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  if [ "$#" -eq 0 ]; then
    usage
    exit 1
  fi

  case "$1" in
  secret)
    shift
    if [ "$#" -ne 1 ]; then
      die "secret command expects exactly one path"
    fi
    update_secret "$1"
    ;;
  sync)
    shift
    sync_documents "$@"
    ;;
  work | w)
    shift || true
    run_coder_env work "$@"
    ;;
  personal | p)
    shift || true
    if [ "${1-}" = go ]; then
      shift || true
      workspace_go "$@"
      return $?
    fi
    run_coder_env personal "$@"
    ;;
  help | -h | --help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
  esac
}

main "$@"
