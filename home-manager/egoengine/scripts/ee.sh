#!/usr/bin/env bash
set -euo pipefail

script_name=${0##*/}

vault=${EE_VAULT:-egoengine}
service_item=${EE_SERVICE_ITEM:-service-account}
work_item=${EE_WORK_ITEM:-work}
personal_item=${EE_PERSONAL_ITEM:-personal}

usage() {
  cat <<'EOF'
Usage:
  ee secret <path>         Upload or update a workspace file in 1Password
  ee work|w [coder args]   Run coder with work environment credentials
  ee personal|p [args]     Run coder with personal environment credentials

Environment:
  EE_VAULT           Override the 1Password vault name (default: egoengine)
  EE_SERVICE_ITEM    Name of the service account note (default: service-account)
  EE_WORK_ITEM       Name of the work env note (default: work)
  EE_PERSONAL_ITEM   Name of the personal env note (default: personal)
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

fetch_note() {
  local item=$1
  op read "op://$vault/$item/notesPlain" 2>/dev/null
}

run_coder_env() {
  require_cmd op
  require_cmd coder

  local env_name=$1
  shift

  local env_item
  case "$env_name" in
    work|w) env_item=$work_item ;;
    personal|p) env_item=$personal_item ;;
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

  local have_url=0
  local have_token=0
  local exported_vars=""

  if [ -n "${service_content//[[:space:]]/}" ]; then
    service_content=$(printf '%s\n' "$service_content" | sed -e 's/\r//g' -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')
    if [ -n "$service_content" ]; then
      export OP_SERVICE_ACCOUNT_TOKEN="$service_content"
      exported_vars="$exported_vars OP_SERVICE_ACCOUNT_TOKEN"
    fi
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*)
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
    exported_vars="$exported_vars $key"

    case "$key" in
      CODER_URL) have_url=1 ;;
      CODER_SESSION_TOKEN) have_token=1 ;;
    esac
  done <<EOF
$env_content
EOF

  if [ "$have_url" -eq 0 ]; then
    die "CODER_URL missing from environment item '$env_item'"
  fi
  if [ "$have_token" -eq 0 ]; then
    die "CODER_SESSION_TOKEN missing from environment item '$env_item'"
  fi

  set +e
  coder "$@"
  local status=$?
  set -e

  for key in $exported_vars; do
    unset "$key"
  done

  return "$status"
}

main() {
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
    work|w)
      shift || true
      run_coder_env work "$@"
      ;;
    personal|p)
      shift || true
      run_coder_env personal "$@"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
