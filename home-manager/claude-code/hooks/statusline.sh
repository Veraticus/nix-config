#!/usr/bin/env bash
# statusline.sh - Claude Code status line that mimics starship prompt
#
# This script generates a status line for Claude Code that matches the
# starship configuration with Catppuccin Mocha colors and powerline separators.

# Individual operations have their own timeouts for better control
# No global timeout wrapper needed

# Enable timing if DEBUG_TIMING is set
if [[ "${DEBUG_TIMING:-}" == "1" ]]; then
  exec 3>&2 # Save stderr
  TIMING_LOG="/tmp/statusline_timing_$$"
  : >"$TIMING_LOG"

  time_point() {
    local label="$1"
    echo "$(date +%s%3N) $label" >>"$TIMING_LOG"
  }

  finish_timing() {
    if [[ -f "$TIMING_LOG" ]]; then
      awk 'NR==1{start=$1} {printf "[%4dms] %s\n", $1-start, substr($0, index($0, $2))}' "$TIMING_LOG" >&3
      rm -f "$TIMING_LOG"
    fi
  }
  trap finish_timing EXIT
else
  time_point() { :; }
  finish_timing() { :; }
fi

time_point "START"

# Helper function to get file modification time (works on both macOS and Linux)
# Define early as it's needed for cache checks
get_file_mtime() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "0"
    return
  fi

  # Try macOS native stat first (if available)
  if [[ -x /usr/bin/stat ]]; then
    /usr/bin/stat -f "%m" "$file" 2>/dev/null || echo "0"
  else
    # Fall back to GNU stat
    stat -c %Y "$file" 2>/dev/null || echo "0"
  fi
}

# Read JSON input FIRST to check cache
time_point "before_read_stdin"
input=$(cat)
time_point "after_read_stdin"

# Quick parse to get cache key (use project directory as main variable)
time_point "before_cache_check"
CURRENT_DIR_FOR_CACHE=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // "~"' 2>/dev/null || echo "~")
CACHE_KEY="$(echo -n "$CURRENT_DIR_FOR_CACHE" | md5sum | cut -d' ' -f1)"

# Use RAM-based /dev/shm to avoid SSD wear from frequent cache checks
# Allow override for testing
CACHE_DIR="${CLAUDE_STATUSLINE_CACHE_DIR:-/dev/shm}"
CACHE_FILE="${CACHE_DIR}/claude_statusline_${CACHE_KEY}"

# Configurable cache duration (default 20 seconds)
# This reduces computation from 180/minute to just 3/minute
CACHE_DURATION="${CLAUDE_STATUSLINE_CACHE_SECONDS:-20}"

# Check data cache
USE_CACHE=0
if [[ -f "$CACHE_FILE" ]]; then
  age=$(($(date +%s) - $(get_file_mtime "$CACHE_FILE")))
  if [[ $age -lt $CACHE_DURATION ]]; then
    time_point "cache_hit"
    # Load cached data from RAM
    # shellcheck source=/dev/null
    source "$CACHE_FILE"
    USE_CACHE=1
  fi
fi

if [[ $USE_CACHE -eq 0 ]]; then
  time_point "cache_miss"
fi

# Source common helpers for colors (though we'll need more specific ones)
time_point "before_source"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common-helpers.sh"
time_point "after_source"

# ============================================================================
# CATPPUCCIN MOCHA COLORS - True color (24-bit) support
# ============================================================================

# Using true color escape sequences for exact Catppuccin Mocha colors
LAVENDER_BG="\033[48;2;180;190;254m" # #b4befe
LAVENDER_FG="\033[38;2;180;190;254m"
GREEN_BG="\033[48;2;166;227;161m" # #a6e3a1
GREEN_FG="\033[38;2;166;227;161m"
MAUVE_BG="\033[48;2;203;166;247m" # #cba6f7
MAUVE_FG="\033[38;2;203;166;247m"
ROSEWATER_BG="\033[48;2;245;224;220m" # #f5e0dc
ROSEWATER_FG="\033[38;2;245;224;220m"
SKY_BG="\033[48;2;137;220;235m" # #89dceb
SKY_FG="\033[38;2;137;220;235m"
YELLOW_BG="\033[48;2;249;226;175m" # #f9e2af (Catppuccin Mocha yellow)
YELLOW_FG="\033[38;2;249;226;175m"
PEACH_BG="\033[48;2;250;179;135m" # #fab387
PEACH_FG="\033[38;2;250;179;135m"
TEAL_BG="\033[48;2;148;226;213m" # #94e2d5
TEAL_FG="\033[38;2;148;226;213m"
RED_BG="\033[48;2;243;139;168m" # #f38ba8 (Catppuccin Mocha red)
RED_FG="\033[38;2;243;139;168m"
BASE_FG="\033[38;2;30;30;46m" # #1e1e2e (dark text on colored backgrounds)
# shellcheck disable=SC2034
BASE_BG="\033[48;2;30;30;46m" # #1e1e2e (same dark color as BASE_FG for progress bar)

# Lighter background variants for progress bar empty sections (muted versions of each color)
GREEN_LIGHT_BG="\033[48;2;86;127;81m"   # Muted green (darker version of #a6e3a1)
YELLOW_LIGHT_BG="\033[48;2;149;136;95m" # Muted yellow (darker version of #f9e2af)
PEACH_LIGHT_BG="\033[48;2;150;107;81m"  # Muted peach (darker version of #fab387)
RED_LIGHT_BG="\033[48;2;146;83;100m"    # Muted red (darker version of #f38ba8)

# Powerline characters
LEFT_CHEVRON=""
LEFT_CURVE=""
RIGHT_CURVE=""
RIGHT_CHEVRON=""

# Icons for different sections (customize as needed)
GIT_ICON="  "
AWS_ICON="  "
K8S_ICON=" ☸ "
DEVSPACE_ICON="" # Will be set based on devspace name
HOSTNAME_ICON=" "
CONTEXT_ICON=" "
MODEL_ICONS="󰚩󱚝󱚟󱚡󱚣󱚥"

# Context bar characters - customize these for the progress bar appearance
# shellcheck disable=SC2034  # Some are unused but kept for future customization
PROGRESS_LEFT_EMPTY=""
PROGRESS_MID_EMPTY=""
PROGRESS_RIGHT_EMPTY=""
PROGRESS_LEFT_FULL=""
PROGRESS_MID_FULL=""
PROGRESS_RIGHT_FULL=""

# ============================================================================
# MAIN LOGIC
# ============================================================================

# Only parse JSON if we don't have cached data
if [[ $USE_CACHE -eq 0 ]]; then
  # Parse ALL JSON values at once (single jq invocation for performance)
  # Input already read above for cache check
  time_point "before_jq_parse"
  json_values=$(echo "$input" | timeout 0.1s jq -r '
      (.model.display_name // "Claude") + "|" +
      (.workspace.project_dir // .workspace.current_dir // .cwd // "~") + "|" +
      (.transcript_path // "")
  ' 2>/dev/null || echo "Claude|~|")
  time_point "after_jq_parse"

  # Split the parsed values
  IFS='|' read -r MODEL_DISPLAY CURRENT_DIR TRANSCRIPT_PATH <<<"$json_values"
fi

# Always select a random icon (doesn't need caching)
ICON_COUNT=${#MODEL_ICONS}
RANDOM_INDEX=$((RANDOM % ICON_COUNT))
MODEL_ICON="${MODEL_ICONS:$RANDOM_INDEX:1} "

# We'll handle transcript search later with other cached operations
# But we need to define functions here so they're available in subshells

# Get terminal width - complex operation so we cache it
get_terminal_width() {
  # Try environment variable first (fastest)
  if [[ -n "${COLUMNS:-}" ]] && [[ "$COLUMNS" -gt 0 ]]; then
    echo "$COLUMNS"
    return
  fi

  # Check if we're in tmux and get width directly from tmux
  if [[ -n "${TMUX:-}" ]]; then
    local tmux_width
    tmux_width=$(tmux display-message -p '#{window_width}' 2>/dev/null)
    if [[ -n "$tmux_width" ]] && [[ "$tmux_width" -gt 0 ]]; then
      echo "$tmux_width"
      return
    fi
  fi

  # Walk up process tree to find a TTY - works on both macOS and Linux
  local current_pid=$$
  local attempts=0

  while [[ $attempts -lt 10 ]] && [[ $current_pid -gt 1 ]]; do
    # Get the parent PID
    local parent_pid
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS: use ps
      parent_pid=$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ')
    elif [[ -r "/proc/$current_pid/stat" ]]; then
      # Linux: use /proc
      parent_pid=$(awk '{print $4}' "/proc/$current_pid/stat" 2>/dev/null)
    else
      break
    fi

    if [[ -z "$parent_pid" ]] || [[ "$parent_pid" == "0" ]]; then
      break
    fi

    # Check if this process has a TTY
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS: check via ps
      local tty_device
      tty_device=$(ps -o tty= -p "$parent_pid" 2>/dev/null | tr -d ' ')

      if [[ -n "$tty_device" ]] && [[ "$tty_device" != "??" ]] && [[ "$tty_device" != "?" ]]; then
        # Found a TTY - try to get its size
        local stty_result
        local tty_path
        if [[ "$tty_device" =~ ^s[0-9]+ ]]; then
          tty_path="/dev/tty$tty_device"
        elif [[ "$tty_device" =~ ^ttys[0-9]+ ]]; then
          tty_path="/dev/$tty_device"
        else
          tty_path="/dev/$tty_device"
        fi

        # Use native macOS stty if available, otherwise try GNU stty
        if [[ -x /bin/stty ]]; then
          # Native macOS stty with -f flag
          stty_result=$(/bin/stty -f "$tty_path" size 2>/dev/null || true)
        elif [[ -x /usr/bin/stty ]]; then
          # Alternative macOS path
          stty_result=$(/usr/bin/stty -f "$tty_path" size 2>/dev/null || true)
        else
          # Try GNU stty by redirecting stdin
          stty_result=$(stty size <"$tty_path" 2>/dev/null || true)
        fi

        if [[ -n "$stty_result" ]]; then
          local width
          width=$(echo "$stty_result" | awk '{print $2}')
          if [[ -n "$width" ]] && [[ "$width" -gt 0 ]]; then
            echo "$width"
            return
          fi
        fi
      fi
    elif [[ -e "/proc/$parent_pid/fd/0" ]]; then
      # Linux: check via /proc
      local tty_path
      tty_path=$(readlink "/proc/$parent_pid/fd/0" 2>/dev/null)

      if [[ "$tty_path" =~ ^/dev/(pts/|tty) ]]; then
        # Get terminal size from this TTY
        local stty_output
        stty_output=$(stty size <"$tty_path" 2>/dev/null || true)
        if [[ -n "$stty_output" ]]; then
          local width
          width=$(echo "$stty_output" | awk '{print $2}')
          if [[ -n "$width" ]] && [[ "$width" -gt 0 ]]; then
            echo "$width"
            return
          fi
        fi
      fi
    fi

    current_pid=$parent_pid
    ((attempts++))
  done

  # Try tput cols as fallback
  if command -v tput >/dev/null 2>&1; then
    local tput_width
    tput_width=$(tput cols 2>/dev/null)
    if [[ -n "$tput_width" ]] && [[ "$tput_width" -gt 0 ]]; then
      echo "$tput_width"
      return
    fi
  fi

  # Default to a wider width since most modern terminals are wide
  echo "210"
}

# Get token metrics if transcript is available (accurate version)
get_token_metrics() {
  local transcript="$1"
  if [[ -z "$transcript" ]] || [[ ! -f "$transcript" ]]; then
    echo "0|0|0|0"
    return
  fi

  # Read the full transcript for accurate token counts
  # Only takes ~7ms even for large files, worth it for accuracy
  local result
  # shellcheck disable=SC2016  # Single quotes are correct for jq script
  result=$(timeout 0.2s jq -s -r '
            map(select(.message.usage != null)) |
            if length == 0 then
                "0|0|0|0"
            else
                (map(.message.usage.input_tokens // 0) | add) as $input |
                (map(.message.usage.output_tokens // 0) | add) as $output |
                (map(.message.usage.cache_read_input_tokens // 0) | add) as $cached |
                (last | .message.usage | 
                    ((.input_tokens // 0) + 
                     (.cache_read_input_tokens // 0) + 
                     (.cache_creation_input_tokens // 0))) as $context |
                "\($input)|\($output)|\($cached)|\($context)"
            end
        ' <"$transcript" 2>/dev/null)

  if [[ -n "$result" ]]; then
    echo "$result"
  else
    echo "0|0|0|0"
  fi
}

# Format directory path (similar to starship truncation)
format_path() {
  local path="$1"
  local home="${HOME}"

  # Replace home with ~
  if [[ "$path" == "$home"* ]]; then
    path="~${path#"$home"}"
  fi

  # If path is longer than 2 directories, truncate with …
  local IFS='/'
  read -ra PARTS <<<"$path"
  local num_parts=${#PARTS[@]}

  if [[ $num_parts -gt 3 ]]; then
    # Keep first part (~ or /), … , last 2 parts
    if [[ "${PARTS[0]}" == "~" ]]; then
      # Using printf to avoid tilde expansion issues
      printf '%s/%s/%s\n' "~" "${PARTS[-2]}" "${PARTS[-1]}"
    else
      echo "…/${PARTS[-2]}/${PARTS[-1]}"
    fi
  else
    echo "$path"
  fi
}

# Truncate text to a maximum length with ellipsis
truncate_text() {
  local text="$1"
  local max_length="$2"

  # Count actual display width (handles UTF-8)
  local length
  length=$(echo -n "$text" | wc -m | tr -d ' ')

  if [[ $length -le $max_length ]]; then
    echo "$text"
  else
    # Leave room for ellipsis (…)
    local truncate_at=$((max_length - 1))
    # Use printf to properly handle UTF-8 truncation
    local truncated
    truncated=$(echo "$text" | cut -c1-${truncate_at})
    echo "${truncated}…"
  fi
}

# Get git information by reading .git directory directly (like starship)
# This is MUCH faster than calling git commands
get_git_info() {
  local git_branch=""
  local git_status=""
  local git_dir=""

  # Find .git directory (walk up tree)
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      git_dir="$dir/.git"
      break
    elif [[ -f "$dir/.git" ]]; then
      # Handle git worktrees (file contains path to actual git dir)
      git_dir=$(grep "^gitdir:" "$dir/.git" 2>/dev/null | cut -d: -f2- | tr -d ' ')
      if [[ -n "$git_dir" && -d "$git_dir" ]]; then
        break
      fi
    fi
    dir=$(dirname "$dir")
  done

  # If no git dir found, return empty
  if [[ -z "$git_dir" ]]; then
    echo "|"
    return
  fi

  # Read branch from HEAD file
  if [[ -f "$git_dir/HEAD" ]]; then
    local head_content
    head_content=$(cat "$git_dir/HEAD" 2>/dev/null)
    if [[ "$head_content" =~ ^ref:\ refs/heads/(.+)$ ]]; then
      git_branch="${BASH_REMATCH[1]}"
    elif [[ "$head_content" =~ ^[0-9a-f]{40}$ ]]; then
      # Detached HEAD - show short hash
      git_branch="${head_content:0:7}"
    fi
  fi

  # Check for uncommitted changes
  # Quick checks: index modified recently, or MERGE_HEAD exists
  if [[ -f "$git_dir/index" ]]; then
    # If index was modified in last 60 seconds, likely have changes
    local index_age=$(($(date +%s) - $(get_file_mtime "$git_dir/index")))
    if [[ $index_age -lt 60 ]]; then
      git_status="!"
    fi
  fi

  # Also check for merge/rebase states
  if [[ -f "$git_dir/MERGE_HEAD" ]] || [[ -d "$git_dir/rebase-merge" ]] || [[ -d "$git_dir/rebase-apply" ]]; then
    git_status="!"
  fi

  echo "${git_branch}|${git_status}"
}

# Get kubernetes context by reading kubeconfig directly (like starship does)
# This is MUCH faster than calling kubectl
get_k8s_context() {
  # Allow test override via CLAUDE_STATUSLINE_KUBECONFIG
  local kubeconfig="${CLAUDE_STATUSLINE_KUBECONFIG:-${KUBECONFIG:-$HOME/.kube/config}}"

  # Check if file exists and is readable (not /dev/null)
  if [[ ! -f "$kubeconfig" ]] || [[ "$kubeconfig" == "/dev/null" ]]; then
    return
  fi

  # Try to extract current-context directly
  # First try grep for speed (works with both JSON and YAML)
  local context
  context=$(grep -m1 "current-context:" "$kubeconfig" 2>/dev/null | sed 's/.*current-context:[[:space:]]*//' | tr -d '"')

  # If that worked and isn't empty, use it
  if [[ -n "$context" ]]; then
    echo "$context"
    return
  fi

  # Fallback to jq for JSON format (some tools write JSON kubeconfig)
  if [[ "$(head -c1 "$kubeconfig" 2>/dev/null)" == "{" ]]; then
    context=$(jq -r '.["current-context"] // empty' "$kubeconfig" 2>/dev/null)
    if [[ -n "$context" ]]; then
      echo "$context"
    fi
  fi
}

# Get hostname (short form) - will be cached later if needed
time_point "before_hostname"
if [[ -z "${HOSTNAME:-}" ]]; then
  HOSTNAME=$(timeout 0.02s hostname -s 2>/dev/null || timeout 0.02s hostname 2>/dev/null || echo "unknown")
fi
# Apply test override if set
if [[ -n "${CLAUDE_STATUSLINE_HOSTNAME:-}" ]]; then
  HOSTNAME="${CLAUDE_STATUSLINE_HOSTNAME}"
fi
time_point "after_hostname"

# Check if we're in tmux and get devspace - will be cached later if needed
time_point "before_devspace"
DEVSPACE=""
DEVSPACE_SYMBOL=""
# Check for TMUX_DEVSPACE environment variable (it might be set even outside tmux)
# Allow test override via CLAUDE_STATUSLINE_DEVSPACE
if [[ -v CLAUDE_STATUSLINE_DEVSPACE ]]; then
  # Test override is set (even if empty), use it
  TMUX_DEVSPACE="${CLAUDE_STATUSLINE_DEVSPACE}"
else
  # No test override, use normal TMUX_DEVSPACE
  TMUX_DEVSPACE="${TMUX_DEVSPACE:-}"
fi
if [[ -n "${TMUX_DEVSPACE}" ]] && [[ "${TMUX_DEVSPACE}" != "-TMUX_DEVSPACE" ]]; then
  case "$TMUX_DEVSPACE" in
  mercury) DEVSPACE_SYMBOL="☿" ;;
  venus) DEVSPACE_SYMBOL="♀" ;;
  earth) DEVSPACE_SYMBOL="♁" ;;
  mars) DEVSPACE_SYMBOL="♂" ;;
  jupiter) DEVSPACE_SYMBOL="♃" ;;
  *) DEVSPACE_SYMBOL="●" ;;
  esac
  DEVSPACE_ICON="${DEVSPACE_SYMBOL}" # Use the planet symbol as the icon
  DEVSPACE="${DEVSPACE_ICON} ${TMUX_DEVSPACE}"
fi
time_point "after_devspace"

# Format the directory
DIR_PATH=$(format_path "$CURRENT_DIR")

# Note: We use simple caching with /dev/shm (RAM) to avoid disk I/O
# All expensive operations are computed once and cached for CACHE_DURATION seconds

# transcript_path is provided directly in the JSON input, no need to search for it!

# Skip expensive operations if we have cached data
if [[ $USE_CACHE -eq 0 ]]; then

  # Compute all data directly (no complex parallel operations or individual caches)
  time_point "before_compute"

  # Get git information
  IFS='|' read -r GIT_BRANCH GIT_STATUS <<<"$(get_git_info)"

  # Get terminal width
  RAW_TERM_WIDTH=$(get_terminal_width)
  if [[ -z "$RAW_TERM_WIDTH" ]] || [[ "$RAW_TERM_WIDTH" -eq 0 ]]; then
    RAW_TERM_WIDTH=210 # Fallback default
  fi

  # Get Kubernetes context
  K8S_CONTEXT=$(get_k8s_context)

  # Get token metrics if transcript exists
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    IFS='|' read -r INPUT_TOKENS OUTPUT_TOKENS _ CONTEXT_LENGTH <<<"$(get_token_metrics "$TRANSCRIPT_PATH")"
  else
    INPUT_TOKENS=0
    OUTPUT_TOKENS=0
    CONTEXT_LENGTH=0
  fi

  time_point "after_compute"

  # Save all data to cache file
  cat >"$CACHE_FILE" <<EOF
# Cached statusline data
MODEL_DISPLAY="$MODEL_DISPLAY"
CURRENT_DIR="$CURRENT_DIR"
TRANSCRIPT_PATH="$TRANSCRIPT_PATH"
GIT_BRANCH="$GIT_BRANCH"
GIT_STATUS="$GIT_STATUS"
K8S_CONTEXT="$K8S_CONTEXT"
INPUT_TOKENS="$INPUT_TOKENS"
OUTPUT_TOKENS="$OUTPUT_TOKENS"
CONTEXT_LENGTH="$CONTEXT_LENGTH"
HOSTNAME="$HOSTNAME"
DEVSPACE="$DEVSPACE"
DEVSPACE_SYMBOL="$DEVSPACE_SYMBOL"
RAW_TERM_WIDTH="$RAW_TERM_WIDTH"
EOF

fi # End of cache miss block

# Terminal width is already set from cache or parallel detection above

# Format token count for display
format_tokens() {
  local count=$1
  if [[ $count -ge 1000000 ]]; then
    printf "%.1fM" "$(awk "BEGIN {printf \"%.1f\", $count / 1000000}")"
  elif [[ $count -ge 1000 ]]; then
    printf "%.1fk" "$(awk "BEGIN {printf \"%.1f\", $count / 1000}")"
  else
    echo "$count"
  fi
}

# Create context usage bar
create_context_bar() {
  local context_length=$1
  local bar_width=$2 # This is now the exact width for the bar

  # Calculate percentage using 160k as the practical limit (auto-compact threshold)
  # This matches when Claude shows the "Context left" warning
  local percentage=0
  if [[ $context_length -gt 0 ]]; then
    percentage=$(awk "BEGIN {printf \"%.1f\", $context_length * 100 / 160000}")
    # Cap at 100% for display
    if awk "BEGIN {exit !($percentage > 100)}"; then
      percentage="100.0"
    fi
  fi

  # Use the passed width directly
  local available_width=$bar_width

  # Minimum bar width (for "Context: XX.X%")
  local min_width=20
  if [[ $available_width -lt $min_width ]]; then
    # Not enough space for bar
    echo ""
    return
  fi

  # Bar components
  local label="${CONTEXT_ICON}Context "
  local percent_text=" ${percentage}%" # Space before percentage
  # Count characters but account for wide icon
  # CONTEXT_ICON is 1 character but displays as 2 columns
  local label_char_count percent_length
  label_char_count=$(echo -n "$label" | wc -m | tr -d ' ')
  percent_length=$(echo -n "$percent_text" | wc -m | tr -d ' ')
  # Add 1 for the context icon being wide
  local text_length=$((label_char_count + percent_length + 1 + 1)) # +1 for space after percent, +1 for wide icon

  # Calculate bar fill width (minus curves and text)
  local fill_width=$((available_width - text_length - 2)) # -2 for curves
  if [[ $fill_width -lt 4 ]]; then
    # Too small for a meaningful bar
    echo ""
    return
  fi

  # Calculate filled portion (cap at 100% for display)
  local display_percentage=$percentage
  if awk "BEGIN {exit !($display_percentage > 100)}"; then
    display_percentage=100
  fi
  local filled_width
  filled_width=$(awk "BEGIN {printf \"%.0f\", $fill_width * $display_percentage / 100}")
  filled_width=${filled_width%.*} # Remove decimal part

  # Choose colors based on percentage of 200k limit
  # < 40% = Green (plenty of space)
  # 40-60% = Yellow (getting full)
  # 60-80% = Peach (approaching auto-compact at 80%)
  # >= 80% = Red (auto-compact triggered at 160k)
  local bg_color fg_color fg_light_bg
  if awk "BEGIN {exit !($percentage < 40)}"; then
    # Green - plenty of space
    bg_color="${GREEN_BG}"
    fg_color="${GREEN_FG}"
    fg_light_bg="${GREEN_LIGHT_BG}"
  elif awk "BEGIN {exit !($percentage < 60)}"; then
    # Yellow - getting full
    bg_color="${YELLOW_BG}"
    fg_color="${YELLOW_FG}"
    fg_light_bg="${YELLOW_LIGHT_BG}"
  elif awk "BEGIN {exit !($percentage < 80)}"; then
    # Peach - approaching auto-compact threshold
    bg_color="${PEACH_BG}"
    fg_color="${PEACH_FG}"
    fg_light_bg="${PEACH_LIGHT_BG}"
  else
    # Red - auto-compact triggered (160k+ tokens)
    bg_color="${RED_BG}"
    fg_color="${RED_FG}"
    fg_light_bg="${RED_LIGHT_BG}"
  fi

  # Create bar with Nerd Font progress characters
  # Filled sections: progress color foreground on dark background (BASE_BG)
  # Unfilled sections: progress color foreground on muted progress color background
  local bar=""
  local i
  for ((i = 0; i < fill_width; i++)); do
    local char=""
    local section=""

    # Determine which character to use based on position and fill status
    if [[ $i -eq 0 ]]; then
      # Left edge
      char="${PROGRESS_LEFT_FULL}"
      # Filled: fg color on dark bg
      section="${fg_light_bg}${fg_color}${char}${NC}"
    elif [[ $i -eq $((fill_width - 1)) ]]; then
      # Right edge
      if [[ $i -lt $filled_width ]]; then
        char="${PROGRESS_RIGHT_FULL}"
        # Filled: fg color on dark bg
        section="${fg_light_bg}${fg_color}${char}${NC}"
      else
        char="${PROGRESS_RIGHT_EMPTY}"
        # Unfilled: fg color on muted bg
        section="${fg_light_bg}${fg_color}${char}${NC}"
      fi
    else
      # Middle sections
      if [[ $i -lt $filled_width ]]; then
        char="${PROGRESS_MID_FULL}"
        # Filled: fg color on dark bg
        section="${fg_light_bg}${fg_color}${char}${NC}"
      else
        char="${PROGRESS_MID_EMPTY}"
        # Unfilled: fg color on muted bg
        section="${fg_light_bg}${fg_color}${char}${NC}"
      fi
    fi

    bar="${bar}${section}"
  done

  # Build the complete bar:
  # Left cap and label: progress color bg, space gray fg
  # Progress bar: as built above
  # Right cap and percentage: progress color bg, space gray fg
  echo "${fg_color}${LEFT_CURVE}${NC}${bg_color}${BASE_FG}${label}${NC}${bar}${bg_color}${BASE_FG}${percent_text} ${NC}${fg_color}${RIGHT_CURVE}${NC}"
}

# Use full model name (no shortening)

# ============================================================================
# BUILD STATUS LINE
# ============================================================================

# Calculate terminal width for right-alignment

# Terminal width already retrieved in parallel section above

# If we can't detect width, use a reasonable default
if [[ $RAW_TERM_WIDTH -eq 0 ]]; then
  RAW_TERM_WIDTH=130 # Reasonable default that won't wrap on most terminals
fi

# Token metrics already retrieved in parallel section above

# Debug context length
if [[ "${STATUSLINE_DEBUG:-}" == "1" ]]; then
  >&2 echo "DEBUG: CONTEXT_LENGTH=$CONTEXT_LENGTH, INPUT_TOKENS=$INPUT_TOKENS, TRANSCRIPT_PATH=$TRANSCRIPT_PATH"
fi

# Store raw terminal width for later calculations
TERM_WIDTH=$RAW_TERM_WIDTH

# Function to calculate visible length (excluding ANSI codes)
strip_ansi() {
  local text="$1"
  # Remove all ANSI escape sequences using printf to interpret escape codes
  printf '%s' "$text" | sed 's/\x1b\[[0-9;:]*m//g'
}

# Start with directory (left side)
STATUS_LINE=""

# In compact mode, we need to be more aggressive with truncation
# Normal mode: 210 chars available, Compact mode: 169 chars available
if [[ $CONTEXT_LENGTH -ge 128000 ]]; then
  # Compact mode - be more aggressive with truncation
  DIR_MAX_LEN=15
  MODEL_MAX_LEN=20
  HOSTNAME_MAX_LEN=15
  BRANCH_MAX_LEN=20
  AWS_MAX_LEN=15
  K8S_MAX_LEN=15
  DEVSPACE_MAX_LEN=10
else
  # Normal mode - regular truncation
  DIR_MAX_LEN=20
  MODEL_MAX_LEN=30
  HOSTNAME_MAX_LEN=25
  BRANCH_MAX_LEN=30
  AWS_MAX_LEN=25
  K8S_MAX_LEN=25
  DEVSPACE_MAX_LEN=20
fi

# Truncate directory path
DIR_PATH_TRUNCATED=$(truncate_text "$DIR_PATH" $DIR_MAX_LEN)

# Start with a full reset to clear any leftover ANSI state from Claude Code
# Then build the status line with left curve and directory with lavender background
STATUS_LINE="${NC}${LAVENDER_FG}${LEFT_CURVE}${LAVENDER_BG}${BASE_FG} ${DIR_PATH_TRUNCATED} ${NC}"

# Add model/tokens section with blue background for better contrast with green context bar
STATUS_LINE="${STATUS_LINE}${SKY_BG}${LAVENDER_FG}${LEFT_CHEVRON}${NC}"

# Show model name and token usage
# Truncate model name using dynamic length
MODEL_DISPLAY_TRUNCATED=$(truncate_text "$MODEL_DISPLAY" $MODEL_MAX_LEN)

TOKEN_INFO=""
if [[ $INPUT_TOKENS -gt 0 ]] || [[ $OUTPUT_TOKENS -gt 0 ]]; then
  TOKEN_INFO=" ${MODEL_ICON:-}${MODEL_DISPLAY_TRUNCATED} ↑$(format_tokens "$INPUT_TOKENS") ↓$(format_tokens "$OUTPUT_TOKENS")"
else
  TOKEN_INFO=" ${MODEL_ICON:-}${MODEL_DISPLAY_TRUNCATED}"
fi
STATUS_LINE="${STATUS_LINE}${SKY_BG}${BASE_FG}${TOKEN_INFO} ${NC}"

# End the left section
STATUS_LINE="${STATUS_LINE}${SKY_FG}${LEFT_CHEVRON}${NC}"

# Build right side with powerline progression
RIGHT_SIDE=""

# Check for AWS profile (remove "export AWS_PROFILE=" prefix if present)
AWS_PROFILE="${AWS_PROFILE:-}"
AWS_PROFILE="${AWS_PROFILE#export AWS_PROFILE=}"

# K8s context already retrieved in parallel section above

# Start building components that exist
COMPONENTS=()

# Add devspace if present (mauve background)
if [[ -n "$DEVSPACE" ]]; then
  # Truncate devspace using dynamic length
  DEVSPACE_TRUNCATED=$(truncate_text "$DEVSPACE" $DEVSPACE_MAX_LEN)
  COMPONENTS+=("mauve|${DEVSPACE_TRUNCATED}")
fi

# Add hostname (rosewater background)
if [[ -n "$HOSTNAME" ]]; then
  # Truncate hostname using dynamic length
  HOSTNAME_TRUNCATED=$(truncate_text "$HOSTNAME" $HOSTNAME_MAX_LEN)
  HOSTNAME_TEXT="${HOSTNAME_ICON}${HOSTNAME_TRUNCATED}"
  COMPONENTS+=("rosewater|${HOSTNAME_TEXT}")
fi

# Add git branch (sky background)
if [[ -n "$GIT_BRANCH" ]]; then
  # Truncate git branch using dynamic length
  GIT_BRANCH_TRUNCATED=$(truncate_text "$GIT_BRANCH" $BRANCH_MAX_LEN)
  GIT_TEXT="${GIT_ICON}${GIT_BRANCH_TRUNCATED}"
  if [[ -n "$GIT_STATUS" ]]; then
    GIT_TEXT="${GIT_TEXT} ${GIT_STATUS}"
  fi
  COMPONENTS+=("sky|${GIT_TEXT}")
fi

# Add AWS profile (peach background)
if [[ -n "$AWS_PROFILE" ]]; then
  # Truncate AWS profile using dynamic length
  AWS_PROFILE_TRUNCATED=$(truncate_text "$AWS_PROFILE" $AWS_MAX_LEN)
  COMPONENTS+=("peach|${AWS_ICON}${AWS_PROFILE_TRUNCATED}")
fi

# Add K8s context (teal background)
if [[ -n "$K8S_CONTEXT" ]]; then
  # Shorten common k8s context patterns
  SHORT_K8S="${K8S_CONTEXT}"
  SHORT_K8S="${SHORT_K8S#arn:aws:eks:*:*:cluster/}" # Remove AWS EKS ARN prefix
  SHORT_K8S="${SHORT_K8S#gke_*_*_}"                 # Shorten GKE contexts
  # Truncate K8s context using dynamic length
  SHORT_K8S_TRUNCATED=$(truncate_text "$SHORT_K8S" $K8S_MAX_LEN)
  COMPONENTS+=("teal|${K8S_ICON}${SHORT_K8S_TRUNCATED}")
fi

# Build the right side with powerline separators
PREV_COLOR=""
for component in "${COMPONENTS[@]}"; do
  IFS='|' read -r COLOR TEXT <<<"$component"

  # Add separator from previous color
  # For right side, chevron should have: BG of previous section, FG of next section
  if [[ -n "$PREV_COLOR" ]]; then
    case $PREV_COLOR in
    mauve) RIGHT_SIDE="${RIGHT_SIDE}${MAUVE_BG}${ROSEWATER_FG}${RIGHT_CHEVRON}${NC}" ;;
    rosewater)
      if [[ "$COLOR" == "sky" ]]; then
        RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_BG}${SKY_FG}${RIGHT_CHEVRON}${NC}"
      elif [[ "$COLOR" == "peach" ]]; then
        RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_BG}${PEACH_FG}${RIGHT_CHEVRON}${NC}"
      elif [[ "$COLOR" == "teal" ]]; then
        RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_BG}${TEAL_FG}${RIGHT_CHEVRON}${NC}"
      fi
      ;;
    sky)
      if [[ "$COLOR" == "peach" ]]; then
        RIGHT_SIDE="${RIGHT_SIDE}${SKY_BG}${PEACH_FG}${RIGHT_CHEVRON}${NC}"
      elif [[ "$COLOR" == "teal" ]]; then
        RIGHT_SIDE="${RIGHT_SIDE}${SKY_BG}${TEAL_FG}${RIGHT_CHEVRON}${NC}"
      fi
      ;;
    peach) RIGHT_SIDE="${RIGHT_SIDE}${PEACH_BG}${TEAL_FG}${RIGHT_CHEVRON}${NC}" ;;
    esac
  else
    # First component - add the appropriate chevron
    case $COLOR in
    mauve) RIGHT_SIDE="${RIGHT_SIDE}${MAUVE_FG}${RIGHT_CHEVRON}${NC}" ;;
    rosewater) RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_FG}${RIGHT_CHEVRON}${NC}" ;;
    sky) RIGHT_SIDE="${RIGHT_SIDE}${SKY_FG}${RIGHT_CHEVRON}${NC}" ;;
    peach) RIGHT_SIDE="${RIGHT_SIDE}${PEACH_FG}${RIGHT_CHEVRON}${NC}" ;;
    teal) RIGHT_SIDE="${RIGHT_SIDE}${TEAL_FG}${RIGHT_CHEVRON}${NC}" ;;
    esac
  fi

  # Add the component text with background
  case $COLOR in
  mauve) RIGHT_SIDE="${RIGHT_SIDE}${MAUVE_BG}${BASE_FG} ${TEXT} ${NC}" ;;
  rosewater) RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_BG}${BASE_FG} ${TEXT} ${NC}" ;;
  sky) RIGHT_SIDE="${RIGHT_SIDE}${SKY_BG}${BASE_FG}${TEXT} ${NC}" ;;
  peach) RIGHT_SIDE="${RIGHT_SIDE}${PEACH_BG}${BASE_FG}${TEXT} ${NC}" ;;
  teal) RIGHT_SIDE="${RIGHT_SIDE}${TEAL_BG}${BASE_FG}${TEXT} ${NC}" ;;
  esac

  PREV_COLOR="$COLOR"
done

# Calculate if we're in compact mode FIRST (before adding right curve)
# Use 160k as the denominator to match what the bar shows
# Trigger compact mode at 80% of 160k (128k) to match Claude's behavior
IN_COMPACT_MODE=0
if [[ $CONTEXT_LENGTH -gt 0 ]]; then
  # Calculate percentage based on 160k (auto-compact threshold)
  # shellcheck disable=SC2034
  CONTEXT_PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", $CONTEXT_LENGTH * 100 / 160000}")
  # Trigger compact mode at 80% of 160k (128k tokens)
  if [[ $CONTEXT_LENGTH -ge 128000 ]]; then
    IN_COMPACT_MODE=1
  fi
fi

# Add right curve at the end, including space for compact mode
if [[ -n "$RIGHT_SIDE" ]]; then
  # Get the last color used from components
  if [[ -n "$PREV_COLOR" ]]; then
    case $PREV_COLOR in
    mauve) RIGHT_SIDE="${RIGHT_SIDE}${MAUVE_FG}${RIGHT_CURVE}${NC}" ;;
    rosewater) RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_FG}${RIGHT_CURVE}${NC}" ;;
    sky) RIGHT_SIDE="${RIGHT_SIDE}${SKY_FG}${RIGHT_CURVE}${NC}" ;;
    peach) RIGHT_SIDE="${RIGHT_SIDE}${PEACH_FG}${RIGHT_CURVE}${NC}" ;;
    teal) RIGHT_SIDE="${RIGHT_SIDE}${TEAL_FG}${RIGHT_CURVE}${NC}" ;;
    esac
  fi

  # Add space after curve for compact mode NOW (before measuring)
  if [[ $IN_COMPACT_MODE -eq 1 ]]; then
    RIGHT_SIDE="${RIGHT_SIDE} "
  fi
fi

# Calculate spacing to push right side to the right
# Account for wide characters (icons/symbols take 2 columns)
# Left side calculation:
# - Left curve (powerline): 1
# - Directory path: actual character count
# - Spaces around directory: 2
# - Model section chevron: 1
# - Model icon: 2 (wide character)
# - Model name and tokens: actual character count
# - Spaces in model section: varies
# - End chevron: 1

# Count left side accurately with proper wide character accounting
# Structure: [curve][bg][space][dir][space][chevron][bg][model_icon][model][tokens][space][chevron]
# Note: We always output " ${DIR_PATH_TRUNCATED} " so there's always 2 spaces even if dir is empty
LEFT_LENGTH=1                                         # Left curve (powerline character)
LEFT_LENGTH=$((LEFT_LENGTH + 1))                      # Space before directory
LEFT_LENGTH=$((LEFT_LENGTH + ${#DIR_PATH_TRUNCATED})) # Directory text (no icon here)
LEFT_LENGTH=$((LEFT_LENGTH + 1))                      # Space after directory (always present in output)
LEFT_LENGTH=$((LEFT_LENGTH + 1))                      # Chevron to model section

# Model section: icon + space + model name + optional tokens
# The TOKEN_INFO variable includes: " [icon] ModelName" or " [icon] ModelName ↑X ↓Y"
# But the icon is 2 columns wide even though it's 1 character
# TOKEN_INFO already has the space, icon, and text, but we need to add 1 for icon width
LEFT_LENGTH=$((LEFT_LENGTH + ${#TOKEN_INFO})) # Model section content as counted
LEFT_LENGTH=$((LEFT_LENGTH + 1))              # Add 1 because model icon displays as 2 columns

LEFT_LENGTH=$((LEFT_LENGTH + 1)) # End chevron

# Calculate right side width by counting each component
RIGHT_LENGTH=0

# Only count if we have components
if [[ -n "$DEVSPACE" ]] || [[ -n "$HOSTNAME" ]] || [[ -n "$GIT_BRANCH" ]] || [[ -n "$AWS_PROFILE" ]] || [[ -n "$K8S_CONTEXT" ]]; then
  # First chevron to start right section
  RIGHT_LENGTH=$((RIGHT_LENGTH + 1))

  # Track if we need separators between components
  PREV_COMPONENT=0

  # Add devspace if present
  if [[ -n "$DEVSPACE" ]]; then
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                      # Space before
    RIGHT_LENGTH=$((RIGHT_LENGTH + 2))                      # Planet symbol (wide character)
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                      # Space after symbol
    RIGHT_LENGTH=$((RIGHT_LENGTH + ${#DEVSPACE_TRUNCATED})) # Devspace name text
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                      # Space after
    PREV_COMPONENT=1
  fi

  # Add hostname if present
  if [[ -n "$HOSTNAME" ]]; then
    [[ $PREV_COMPONENT -eq 1 ]] && RIGHT_LENGTH=$((RIGHT_LENGTH + 1)) # Chevron separator
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                                # Space before
    RIGHT_LENGTH=$((RIGHT_LENGTH + 3))                                # HOSTNAME_ICON " " = space + icon (2 cols)
    RIGHT_LENGTH=$((RIGHT_LENGTH + ${#HOSTNAME_TRUNCATED}))           # Hostname text
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                                # Space after
    PREV_COMPONENT=1
  fi

  # Add git branch if present
  if [[ -n "$GIT_BRANCH" ]]; then
    [[ $PREV_COMPONENT -eq 1 ]] && RIGHT_LENGTH=$((RIGHT_LENGTH + 1)) # Chevron separator
    RIGHT_LENGTH=$((RIGHT_LENGTH + 2))                                # Git icon (wide character) - includes space
    RIGHT_LENGTH=$((RIGHT_LENGTH + ${#GIT_BRANCH_TRUNCATED}))         # Branch text
    [[ -n "$GIT_STATUS" ]] && RIGHT_LENGTH=$((RIGHT_LENGTH + 2))      # Space + status char
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                                # Space after
    PREV_COMPONENT=1
  fi

  # Add AWS profile if present
  if [[ -n "$AWS_PROFILE" ]]; then
    [[ $PREV_COMPONENT -eq 1 ]] && RIGHT_LENGTH=$((RIGHT_LENGTH + 1)) # Chevron separator
    RIGHT_LENGTH=$((RIGHT_LENGTH + 3))                                # AWS_ICON " " = icon (2 cols) + space
    RIGHT_LENGTH=$((RIGHT_LENGTH + ${#AWS_PROFILE_TRUNCATED}))        # Profile text
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                                # Space after
    PREV_COMPONENT=1
  fi

  # Add K8s context if present
  if [[ -n "$K8S_CONTEXT" ]]; then
    [[ $PREV_COMPONENT -eq 1 ]] && RIGHT_LENGTH=$((RIGHT_LENGTH + 1)) # Chevron separator
    RIGHT_LENGTH=$((RIGHT_LENGTH + 3))                                # K8S_ICON " ☸ " = space + icon + space
    RIGHT_LENGTH=$((RIGHT_LENGTH + ${#SHORT_K8S_TRUNCATED}))          # Context text
    RIGHT_LENGTH=$((RIGHT_LENGTH + 1))                                # Space after
    PREV_COMPONENT=1
  fi

  # End curve
  RIGHT_LENGTH=$((RIGHT_LENGTH + 1))

  # Add extra space if in compact mode (already added to RIGHT_SIDE string)
  [[ $IN_COMPACT_MODE -eq 1 ]] && RIGHT_LENGTH=$((RIGHT_LENGTH + 1))
fi

# Calculate the exact width we need to work with
# Reserve space for safety margin to prevent overflow
RESERVED_END_CHARS=0 # Safety margin to prevent overflow
if [[ $IN_COMPACT_MODE -eq 1 ]]; then
  # Reserve space for the auto-compact message (space is already in RIGHT_LENGTH)
  COMPACT_MESSAGE_WIDTH=41 # 41 chars for the message itself
else
  COMPACT_MESSAGE_WIDTH=0
fi

# Calculate total available width for our statusline
# Add safety margin to prevent characters falling off the edge
AVAILABLE_WIDTH=$((TERM_WIDTH - RESERVED_END_CHARS - COMPACT_MESSAGE_WIDTH))

# Debug output when requested
if [[ "${STATUSLINE_DEBUG:-}" == "1" ]]; then
  >&2 echo "DEBUG: TERM_WIDTH=$TERM_WIDTH, LEFT_LENGTH=$LEFT_LENGTH, RIGHT_LENGTH=$RIGHT_LENGTH"
  >&2 echo "DEBUG: RESERVED_END_CHARS=$RESERVED_END_CHARS, COMPACT_MESSAGE_WIDTH=$COMPACT_MESSAGE_WIDTH"
  >&2 echo "DEBUG: AVAILABLE_WIDTH=$AVAILABLE_WIDTH"
  >&2 echo "DEBUG: Components: DEVSPACE='$DEVSPACE_TRUNCATED' HOST='$HOSTNAME_TRUNCATED' GIT='$GIT_BRANCH_TRUNCATED' AWS='$AWS_PROFILE_TRUNCATED' K8S='$SHORT_K8S_TRUNCATED'"
fi

# Calculate middle section (context bar or spacing)
SPACE_FOR_MIDDLE=$((AVAILABLE_WIDTH - LEFT_LENGTH - RIGHT_LENGTH))

# Debug middle section calculation
if [[ "${STATUSLINE_DEBUG:-}" == "1" ]]; then
  >&2 echo "DEBUG: SPACE_FOR_MIDDLE=$SPACE_FOR_MIDDLE (AVAILABLE=$AVAILABLE_WIDTH - LEFT=$LEFT_LENGTH - RIGHT=$RIGHT_LENGTH)"
fi

if [[ $CONTEXT_LENGTH -gt 0 ]]; then
  # We have token metrics - try to show a context bar
  if [[ $SPACE_FOR_MIDDLE -gt 20 ]]; then
    # We have enough space for a context bar with some padding
    # Reserve some space for padding around the bar (minimum 2 on each side)
    PADDING_TOTAL=10 # 5 spaces on each side
    BAR_WIDTH=$((SPACE_FOR_MIDDLE - PADDING_TOTAL))

    if [[ $BAR_WIDTH -lt 20 ]]; then
      # Bar would be too small, use all available space with minimal padding
      PADDING_TOTAL=4 # 2 on each side
      BAR_WIDTH=$((SPACE_FOR_MIDDLE - PADDING_TOTAL))
    fi

    if [[ $BAR_WIDTH -gt 0 ]]; then
      CONTEXT_BAR=$(create_context_bar "$CONTEXT_LENGTH" "$BAR_WIDTH")
      if [[ "${STATUSLINE_DEBUG:-}" == "1" ]]; then
        >&2 echo "DEBUG: Created context bar with width $BAR_WIDTH, bar length: ${#CONTEXT_BAR}"
      fi
      # Distribute padding evenly
      LEFT_PAD=$((PADDING_TOTAL / 2))
      RIGHT_PAD=$((PADDING_TOTAL - LEFT_PAD))
      MIDDLE_SECTION=$(printf '%*s%s%*s' $LEFT_PAD '' "$CONTEXT_BAR" $RIGHT_PAD '')
    else
      # Not enough space for a bar, just use spacing
      MIDDLE_SECTION=$(printf '%*s' $SPACE_FOR_MIDDLE '')
    fi
  else
    # Not enough space for context bar, just use spacing
    MIDDLE_SECTION=$(printf '%*s' $SPACE_FOR_MIDDLE '')
  fi
else
  # No context bar, just use spacing to right-align
  MIDDLE_SECTION=$(printf '%*s' $SPACE_FOR_MIDDLE '')
fi

# Debug the actual middle section length
if [[ "${STATUSLINE_DEBUG:-}" == "1" ]]; then
  >&2 echo "DEBUG: MIDDLE_SECTION length=${#MIDDLE_SECTION}, SPACE_FOR_MIDDLE=$SPACE_FOR_MIDDLE"
fi

# Output the statusline (no newline - statusline should be exact width)
time_point "before_output"
printf '%b' "${STATUS_LINE}${MIDDLE_SECTION}${RIGHT_SIDE}"
time_point "after_output"
