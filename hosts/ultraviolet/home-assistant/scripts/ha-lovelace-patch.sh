#!/usr/bin/env bash
# Home Assistant Lovelace helper (fetch, patch with jq, save)

set -euo pipefail

dash=""
filter=""
filter_file=""
builtin_longpress=false
dry_run=false
list_only=false
print_only=false

print_help() {
  cat <<'USAGE'
Usage examples:
  # List dashboards (url_path and title)
  ha-lovelace-patch --list

  # Print current config JSON for a dashboard
  ha-lovelace-patch -d bubble-overview --print

  # Apply a custom jq filter (inline)
  ha-lovelace-patch -d bubble-overview -F '.views = .views'

  # Apply a jq filter from a file
  ha-lovelace-patch -d bubble-overview -p my-filter.jq

  # Convenience: apply built-in long-press popup patch
  ha-lovelace-patch -d bubble-overview --long-press

  # Preview changes without saving
  ha-lovelace-patch -d bubble-overview --long-press --dry-run

Options:
  -d, --dashboard  Dashboard url_path (e.g., bubble-overview)
  -F, --filter     Inline jq filter to transform config
  -p, --patch      Path to a jq filter file
  -L, --long-press Apply built-in long-press popup patch
  --list           List dashboards and exit
  --print          Print current dashboard JSON and exit
  -n, --dry-run    Show diff but do not save
  -h, --help       Show this help

Notes:
  - Requires hass-cli (from this repo), jq and diff.
  - No HA restart required; refresh your browser to see changes.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dashboard) dash="$2"; shift 2 ;;
    -F|--filter) filter="$2"; shift 2 ;;
    -p|--patch) filter_file="$2"; shift 2 ;;
    -L|--long-press) builtin_longpress=true; shift ;;
    --list) list_only=true; shift ;;
    --print) print_only=true; shift ;;
    -n|--dry-run) dry_run=true; shift ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; print_help; exit 2 ;;
  esac
done

command -v hass-cli >/dev/null 2>&1 || { echo "Error: hass-cli not found in PATH" >&2; exit 127; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq not found in PATH" >&2; exit 127; }

if $list_only; then
  hass-cli -o json raw ws lovelace/dashboards/list | jq -r '.result[] | [.url_path, .title] | @tsv' | column -t || true
  exit 0
fi

if [[ -z "$dash" ]]; then
  echo "Error: --dashboard is required" >&2
  print_help
  exit 2
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

orig="$tmpdir/config.orig.json"
new="$tmpdir/config.new.json"
cfg_orig="$tmpdir/config.orig.cfg.json"
cfg_new="$tmpdir/config.new.cfg.json"

# Fetch current config for the dashboard (WS wrapper)
hass-cli -o json raw ws lovelace/config --json "{\"url_path\":\"$dash\",\"force\":true}" > "$orig"
# Extract the config root from the wrapper
jq -c '.result' "$orig" > "$cfg_orig"

# Create a timestamped backup of the current config
backup_dir="${XDG_CONFIG_HOME:-$HOME/.config}/home-assistant/lovelace-backups"
mkdir -p "$backup_dir"
ts=$(date +%Y%m%d-%H%M%S)
backup_file="$backup_dir/$dash-$ts.json"
cp "$cfg_orig" "$backup_file"

if $print_only; then
  jq . "$cfg_orig"
  exit 0
fi

"${filter_file:+}" &>/dev/null
# Build filter: custom provided or built-in long-press patch, operate on config only
if [[ -n "$filter_file" ]]; then
  jq -c -f "$filter_file" "$cfg_orig" > "$cfg_new"
elif [[ -n "$filter" ]]; then
  jq -c "$filter" "$cfg_orig" > "$cfg_new"
elif $builtin_longpress; then
  jq -c '
    def walk(f):
      . as $in
      | if type == "object" then
          with_entries(.value |= (walk(f)))
        elif type == "array" then
          map(walk(f))
        else .
        end
      | f;
    def longpress:
      walk(
        if ( type == "object"
             and .type? == "custom:bubble-card"
             and .card_type? == "button"
             and .button_type? == "slider" ) then
          ( .sub_button // [] ) as $sb
          | ( [ $sb[]?
                | select( (.tap_action? // {})
                         | (.action? == "navigate" and (.navigation_path? | tostring | startswith("#"))))
                | .tap_action.navigation_path
              ] | .[0]? ) as $nav
          | .sub_button = [ $sb[]?
                | select( (.tap_action? // {})
                      | (.action != "navigate" or (.navigation_path? | tostring | startswith("#") | not))) ]
          | .tap_to_slide = true
          | if $nav then
              ( .button_action = (.button_action // {})
                | .button_action.hold_action = { "action": "navigate", "navigation_path": $nav } )
            else . end
        else . end
      );
    . | longpress
  ' "$cfg_orig" > "$cfg_new"
else
  echo "Error: specify a patch with -F/--filter, -p/--patch, or --long-press" >&2
  print_help
  exit 2
fi

if $dry_run; then
  echo "--- Summary"
  echo "Original bytes: $(wc -c < "$cfg_orig")"
  echo "New bytes:      $(wc -c < "$cfg_new")"
  # Show which cards would be updated (entity/name and nav path)
  echo "Changed slider cards:"
  jq -r '
    def has_nav_sub: (.sub_button // []) | any(.tap_action?.action == "navigate" and (.tap_action.navigation_path|tostring|startswith("#")));
    .views[]? | .cards[]?
    | select(.type == "custom:bubble-card" and .card_type == "button" and .button_type == "slider")
    | select(has_nav_sub)
    | [(.entity // "<no-entity>"), (.name // "<no-name>"), ((.sub_button[]? | select(.tap_action?.action == "navigate") | .tap_action.navigation_path) // "<no-nav>")] 
    | @tsv
  ' "$cfg_orig" | sed 's/^/  - /' || true

  # Pretty diff without process substitution (for broader shell support)
  pp_orig="$tmpdir/orig.pp.json"; pp_new="$tmpdir/new.pp.json"
  jq -S . "$cfg_orig" > "$pp_orig"
  jq -S . "$cfg_new" > "$pp_new"
  echo "--- Pretty diff (full config)"
  if command -v diff >/dev/null 2>&1; then
    if ! diff -u "$pp_orig" "$pp_new"; then
      :
    fi
  else
    echo "(diff not found; install diffutils or run 'make update' to enable unified diffs)"
  fi

  # Focused diff for relevant cards only
  echo "--- Focused diff (slider cards only)"
  f_orig="$tmpdir/orig.focus.json"; f_new="$tmpdir/new.focus.json"
  jq -S '
    {views: [ .views[]? | {path, title, cards: [ .cards[]? 
      | select(.type=="custom:bubble-card" and .card_type=="button" and .button_type=="slider")
      | {entity, name, tap_to_slide, button_action, sub_button} ]} ]}
  ' "$cfg_orig" > "$f_orig"
  jq -S '
    {views: [ .views[]? | {path, title, cards: [ .cards[]? 
      | select(.type=="custom:bubble-card" and .card_type=="button" and .button_type=="slider")
      | {entity, name, tap_to_slide, button_action, sub_button} ]} ]}
  ' "$cfg_new" > "$f_new"
  if command -v diff >/dev/null 2>&1; then
    if ! diff -u "$f_orig" "$f_new"; then
      :
    fi
  fi

  # Compact summary diff for quick scan
  echo "--- Summary of changes per card"
  s_orig="$tmpdir/orig.summary"; s_new="$tmpdir/new.summary"
  jq -r '
    .views[]? | .cards[]? 
    | select(.type=="custom:bubble-card" and .card_type=="button" and .button_type=="slider")
    | . as $c
    | $c.sub_button // [] as $sb
    | $c.button_action.hold_action.navigation_path // "<none>" as $hold
    | [($c.entity // "<no-entity>"), ($c.name // "<no-name>"), ([$sb[]? | select(.tap_action?.action=="navigate") | .tap_action.navigation_path] | length), $hold, ($c.tap_to_slide // false)]
    | @tsv
  ' "$cfg_orig" | sort > "$s_orig"
  jq -r '
    .views[]? | .cards[]? 
    | select(.type=="custom:bubble-card" and .card_type=="button" and .button_type=="slider")
    | . as $c
    | $c.sub_button // [] as $sb
    | $c.button_action.hold_action.navigation_path // "<none>" as $hold
    | [($c.entity // "<no-entity>"), ($c.name // "<no-name>"), ([$sb[]? | select(.tap_action?.action=="navigate") | .tap_action.navigation_path] | length), $hold, ($c.tap_to_slide // false)]
    | @tsv
  ' "$cfg_new" | sort > "$s_new"
  if command -v diff >/dev/null 2>&1; then
    if ! diff -u "$s_orig" "$s_new"; then
      :
    fi
  else
    echo "(diff not found; install diffutils to see per-card summary diff)"
  fi
  exit 0
fi

# Save back via WS (send only the config, not the WS wrapper)
payload=$(jq -c --arg url "$dash" --slurpfile cfg "$cfg_new" '{url_path:$url, config: $cfg[0] }')
if ! hass-cli --timeout 15 raw ws lovelace/config/save --json "$payload" >/dev/null; then
  echo "Save failed; leaving backup at $backup_file" >&2
  exit 1
fi

# Validate saved config; if invalid, auto-revert from backup
verify="$tmpdir/verify.json"
sleep 1
if hass-cli --timeout 15 -o json raw ws lovelace/config --json "{\"url_path\":\"$dash\",\"force\":true}" > "$verify"; then
  vtype=$(jq -r '.result | type' "$verify" 2>/dev/null || echo null)
  vviews=$(jq -r '.result.views | length' "$verify" 2>/dev/null || echo 0)
  if [ "$vtype" != "object" ] || [ "$vviews" = "0" ]; then
    echo "Validation failed (type=$vtype views=$vviews). Reverting from $backup_file..." >&2
    revert=$(jq -c --arg url "$dash" --slurpfile cfg "$backup_file" '{url_path:$url, config: $cfg[0] }')
    if hass-cli --timeout 15 raw ws lovelace/config/save --json "$revert" >/dev/null; then
      echo "Reverted to previous config." >&2
      exit 1
    else
      echo "Revert failed. Manual restore needed. Backup at: $backup_file" >&2
      exit 1
    fi
  fi
else
  echo "Validation request failed. Leaving backup at $backup_file" >&2
  exit 1
fi

echo "Saved dashboard '$dash' successfully. Backup: $backup_file"
