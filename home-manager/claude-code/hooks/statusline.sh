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

# Read JSON input FIRST to check cache
time_point "before_read_stdin"
input=$(cat)
time_point "after_read_stdin"

# Quick parse to get cache key (directory is main variable)
time_point "before_cache_check"
CURRENT_DIR_FOR_CACHE=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"' 2>/dev/null || echo "~")
CACHE_KEY="$(echo -n "$CURRENT_DIR_FOR_CACHE" | md5sum | cut -d' ' -f1)"
CACHE_FILE="/tmp/claude_statusline_data_${CACHE_KEY}"

# Check data cache (valid for 5 seconds)
USE_CACHE=0
if [[ -f "$CACHE_FILE" ]]; then
  age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
  if [[ $age -lt 5 ]]; then
    time_point "cache_hit"
    # Load cached data
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

# Parse ALL JSON values at once (single jq invocation for performance)
# Input already read above for cache check
time_point "before_jq_parse"
json_values=$(echo "$input" | timeout 0.1s jq -r '
    (.model.display_name // "Claude") + "|" +
    (.workspace.current_dir // .cwd // "~") + "|" +
    (.transcript_path // "")
' 2>/dev/null || echo "Claude|~|")
time_point "after_jq_parse"

# Split the parsed values
IFS='|' read -r MODEL_DISPLAY CURRENT_DIR TRANSCRIPT_PATH <<<"$json_values"

# Select a random icon from MODEL_ICONS
ICON_COUNT=${#MODEL_ICONS}
RANDOM_INDEX=$((RANDOM % ICON_COUNT))
MODEL_ICON="${MODEL_ICONS:$RANDOM_INDEX:1} "

# We'll handle transcript search later with other cached operations
# But we need to define functions here so they're available in subshells

# Get terminal width - we'll adjust it later based on context percentage
get_terminal_width() {
  # Try environment variable first (fastest)
  if [[ -n "${COLUMNS:-}" ]] && [[ "$COLUMNS" -gt 0 ]]; then
    echo "$COLUMNS"
    return
  fi

  # Try to find the Claude process's TTY via /proc (Linux only)
  if [[ -d /proc ]]; then
    # Walk up the process tree to find a Claude process with a TTY
    local check_pid=$PPID
    local attempts=0

    while [[ $attempts -lt 5 ]] && [[ $check_pid -gt 1 ]]; do
      # Check if this process is claude
      if [[ -r "/proc/$check_pid/comm" ]]; then
        local comm
        comm=$(cat "/proc/$check_pid/comm" 2>/dev/null)

        # If we found claude or we have a TTY, try to get dimensions
        if [[ "$comm" == "claude" ]] || [[ -e "/proc/$check_pid/fd/1" ]]; then
          local tty_path
          tty_path=$(readlink "/proc/$check_pid/fd/1" 2>/dev/null)

          if [[ "$tty_path" =~ ^/dev/(pts/|tty) ]]; then
            # Get terminal size from this TTY with timeout
            local stty_output
            stty_output=$(timeout 0.02s stty size <"$tty_path" 2>/dev/null || true)
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
      fi

      # Get parent PID and continue
      if [[ -r "/proc/$check_pid/stat" ]]; then
        check_pid=$(awk '{print $4}' "/proc/$check_pid/stat" 2>/dev/null)
      else
        break
      fi
      ((attempts++))
    done
  fi

  # Try tput cols as fallback with timeout
  if command -v tput >/dev/null 2>&1; then
    local tput_width
    tput_width=$(timeout 0.02s tput cols 2>/dev/null)
    if [[ -n "$tput_width" ]] && [[ "$tput_width" -gt 0 ]]; then
      echo "$tput_width"
      return
    fi
  fi

  # Default to a wider width since most modern terminals are wide
  echo "160"
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

# Get git information if in a git repo (with timeout for performance)
get_git_info() {
  local git_branch=""
  local git_status=""

  # Use timeout to prevent hanging on slow operations
  if timeout 0.1s git rev-parse --git-dir >/dev/null 2>&1; then
    # Get current branch with timeout
    git_branch=$(timeout 0.05s git branch --show-current 2>/dev/null || echo "")

    # Get git status indicators with timeout (fastest possible check)
    if [[ -n $(timeout 0.05s git status --porcelain 2>/dev/null) ]]; then
      git_status="!"
    fi
  fi

  echo "${git_branch}|${git_status}"
}

# Get hostname (short form) - will be cached later if needed
time_point "before_hostname"
if [[ -z "${HOSTNAME:-}" ]]; then
  HOSTNAME=$(timeout 0.02s hostname -s 2>/dev/null || timeout 0.02s hostname 2>/dev/null || echo "unknown")
fi
time_point "after_hostname"

# Check if we're in tmux and get devspace - will be cached later if needed
time_point "before_devspace"
DEVSPACE=""
DEVSPACE_SYMBOL=""
# Check for TMUX_DEVSPACE environment variable (it might be set even outside tmux)
if [[ -n "${TMUX_DEVSPACE:-}" ]] && [[ "${TMUX_DEVSPACE}" != "-TMUX_DEVSPACE" ]]; then
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

# Set up cache directory for persistent caching
CACHE_DIR="/tmp/claude_statusline_cache"
mkdir -p "$CACHE_DIR"

# Clean up old cache files occasionally (1% chance per run)
if [[ $((RANDOM % 100)) -eq 0 ]]; then
  find "$CACHE_DIR" -type f -mmin +10 -delete 2>/dev/null &
fi

# Function to check cache validity
cache_valid() {
  local cache_file="$1"
  local max_age="${2:-5}" # Default 5 seconds

  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  local age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
  [[ $age -lt $max_age ]]
}

# Function to get cached value or compute it
get_cached() {
  local cache_file="$1"
  local max_age="$2"
  shift 2
  local command="$*"

  if cache_valid "$cache_file" "$max_age"; then
    cat "$cache_file"
  else
    # Run command and cache result
    local result
    result=$(eval "$command" 2>/dev/null)
    echo "$result" >"$cache_file"
    echo "$result"
  fi
}

# Skip expensive operations if we have cached data
if [[ $USE_CACHE -eq 0 ]]; then

  # Find transcript if not in cache and not disabled
  if [[ "${CLAUDE_STATUSLINE_NO_TOKENS:-}" != "1" ]]; then
    if [[ -z "$TRANSCRIPT_PATH" ]] || [[ "$TRANSCRIPT_PATH" == "null" ]]; then
      # Look for most recent transcript in Claude project directory
      # Convert current directory to the sanitized project path format
      PROJECT_PATH="${CURRENT_DIR}"
      # Handle home directory - use appropriate prefix based on OS
      if [[ "$(uname)" == "Darwin" ]]; then
        # macOS uses /Users
        PROJECT_PATH="${PROJECT_PATH/#$HOME/-Users-$(whoami)}"
      else
        # Linux uses /home
        PROJECT_PATH="${PROJECT_PATH/#$HOME/-home-$(whoami)}"
      fi
      # Replace slashes with dashes
      PROJECT_PATH="${PROJECT_PATH//\//-}"

      # Look in ~/.claude/projects/ for this project
      CLAUDE_PROJECT_DIR="${HOME}/.claude/projects/${PROJECT_PATH}"

      if [[ -d "$CLAUDE_PROJECT_DIR" ]]; then
        # Cache transcript path for 5 seconds - changes when new conversation starts
        time_point "before_transcript_search"
        TRANSCRIPT_CACHE="$CACHE_DIR/transcript_$(echo -n "$CLAUDE_PROJECT_DIR" | md5sum | cut -d' ' -f1)"
        if cache_valid "$TRANSCRIPT_CACHE" 5; then
          TRANSCRIPT_PATH=$(cat "$TRANSCRIPT_CACHE")
        else
          # Use simpler ls-based approach with timeout for better performance
          # Get the most recent .jsonl file (ls -t sorts by modification time)
          TRANSCRIPT_PATH=$(timeout 0.1s ls -t "$CLAUDE_PROJECT_DIR"/*.jsonl 2>/dev/null | head -n1)
          if [[ -n "$TRANSCRIPT_PATH" ]]; then
            echo "$TRANSCRIPT_PATH" >"$TRANSCRIPT_CACHE"
          fi
        fi
        time_point "after_transcript_search"

        # If we found a transcript, validate it's recent (within last hour)
        if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
          # Check if file was modified in the last hour
          CURRENT_TIME=$(date +%s)
          # Use explicit path for macOS stat to avoid conflicts
          if [[ -x /usr/bin/stat ]]; then
            FILE_TIME=$(/usr/bin/stat -f "%m" "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
          else
            FILE_TIME=$(stat -c %Y "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
          fi
          TIME_DIFF=$((CURRENT_TIME - FILE_TIME))

          # If file is older than 1 hour (3600 seconds), ignore it
          if [[ $TIME_DIFF -gt 3600 ]]; then
            TRANSCRIPT_PATH=""
          fi
        fi
      fi
    fi
  fi

  # Run expensive operations in parallel using background processes
  time_point "before_parallel_ops"

  # Create temp files for parallel operations
  TMP_DIR="/tmp/claude_statusline_$$"
  mkdir -p "$TMP_DIR"
  # Add cleanup to existing trap if timing is enabled
  if [[ "${DEBUG_TIMING:-}" == "1" ]]; then
    trap 'rm -rf '"$TMP_DIR"'; finish_timing' EXIT
  else
    trap 'rm -rf '"$TMP_DIR" EXIT
  fi

  # Start all expensive operations in parallel
  (
    # Git information - cache for 2 seconds (changes frequently)
    # Include directory in cache key since git info is directory-specific
    GIT_CACHE="$CACHE_DIR/git_$(echo -n "$PWD" | md5sum | cut -d' ' -f1)"
    if cache_valid "$GIT_CACHE" 2; then
      cat "$GIT_CACHE"
    else
      get_git_info | tee "$GIT_CACHE"
    fi >"$TMP_DIR/git_info" 2>/dev/null
  ) &
  GIT_PID=$!

  (
    # Terminal width detection - cache for 10 seconds (rarely changes)
    # Include PPID in cache key since width can vary by terminal
    TERM_CACHE="$CACHE_DIR/term_width_$PPID"
    if cache_valid "$TERM_CACHE" 10; then
      cat "$TERM_CACHE"
    else
      get_terminal_width | tee "$TERM_CACHE"
    fi >"$TMP_DIR/term_width" 2>/dev/null
  ) &
  TERM_PID=$!

  (
    # Kubernetes context - cache for 30 seconds (changes infrequently)
    if command -v kubectl >/dev/null 2>&1; then
      K8S_CACHE="$CACHE_DIR/k8s_context"
      if cache_valid "$K8S_CACHE" 30; then
        cat "$K8S_CACHE"
      else
        timeout 0.1s kubectl config current-context 2>/dev/null | tee "$K8S_CACHE"
      fi
    fi >"$TMP_DIR/k8s_context" 2>/dev/null
  ) &
  K8S_PID=$!

  # Token metrics can run in background too if transcript exists
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    (
      # Cache token metrics for 1 second - changes frequently during conversation
      # Use file modification time as part of cache key
      FILE_MTIME=$(stat -c %Y "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
      TOKEN_CACHE="$CACHE_DIR/tokens_$(echo -n "${TRANSCRIPT_PATH}_${FILE_MTIME}" | md5sum | cut -d' ' -f1)"
      if cache_valid "$TOKEN_CACHE" 1; then
        cat "$TOKEN_CACHE"
      else
        result=$(get_token_metrics "$TRANSCRIPT_PATH")
        echo "$result" | tee "$TOKEN_CACHE"
      fi >"$TMP_DIR/token_metrics"
    ) &
    TOKEN_PID=$!
  fi

  # Wait for all background processes to complete
  if [[ -n "${TOKEN_PID:-}" ]]; then
    wait "$GIT_PID" "$TERM_PID" "$K8S_PID" "$TOKEN_PID"
  else
    wait "$GIT_PID" "$TERM_PID" "$K8S_PID"
  fi

  time_point "after_parallel_ops"

  # Read results from temp files
  time_point "before_read_results"

  # Git information
  if [[ -f "$TMP_DIR/git_info" ]]; then
    IFS='|' read -r GIT_BRANCH GIT_STATUS <"$TMP_DIR/git_info"
  else
    GIT_BRANCH=""
    GIT_STATUS=""
  fi

  # Terminal width
  if [[ -f "$TMP_DIR/term_width" ]]; then
    RAW_TERM_WIDTH=$(cat "$TMP_DIR/term_width")
  else
    RAW_TERM_WIDTH=160
  fi

  # Kubernetes context
  if [[ -f "$TMP_DIR/k8s_context" ]]; then
    K8S_CONTEXT=$(cat "$TMP_DIR/k8s_context")
  else
    K8S_CONTEXT=""
  fi

  # Token metrics
  if [[ -f "$TMP_DIR/token_metrics" ]]; then
    IFS='|' read -r INPUT_TOKENS OUTPUT_TOKENS _ CONTEXT_LENGTH <"$TMP_DIR/token_metrics"
  else
    INPUT_TOKENS=0
    OUTPUT_TOKENS=0
    CONTEXT_LENGTH=0
  fi

  time_point "after_read_results"

  # Save all data to cache file
  cat >"$CACHE_FILE" <<EOF
# Cached statusline data
GIT_BRANCH="$GIT_BRANCH"
GIT_STATUS="$GIT_STATUS"
RAW_TERM_WIDTH="$RAW_TERM_WIDTH"
K8S_CONTEXT="$K8S_CONTEXT"
INPUT_TOKENS="$INPUT_TOKENS"
OUTPUT_TOKENS="$OUTPUT_TOKENS"
CONTEXT_LENGTH="$CONTEXT_LENGTH"
HOSTNAME="$HOSTNAME"
DEVSPACE="$DEVSPACE"
DEVSPACE_SYMBOL="$DEVSPACE_SYMBOL"
TRANSCRIPT_PATH="$TRANSCRIPT_PATH"
EOF

fi # End of cache miss block

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
  # Use wc -m for proper Unicode character width counting
  local label_length percent_length
  label_length=$(echo -n "$label" | wc -m | tr -d ' ')
  percent_length=$(echo -n "$percent_text" | wc -m | tr -d ' ')
  local text_length=$((label_length + percent_length + 1)) # +1 for space after percent

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

# Start with a full reset to clear any leftover ANSI state from Claude Code
# Then build the status line with left curve and directory with lavender background
STATUS_LINE="${NC}${LAVENDER_FG}${LEFT_CURVE}${LAVENDER_BG}${BASE_FG} ${DIR_PATH} ${NC}"

# Add model/tokens section with blue background for better contrast with green context bar
STATUS_LINE="${STATUS_LINE}${SKY_BG}${LAVENDER_FG}${LEFT_CHEVRON}${NC}"

# Show model name and token usage
TOKEN_INFO=""
if [[ $INPUT_TOKENS -gt 0 ]] || [[ $OUTPUT_TOKENS -gt 0 ]]; then
  TOKEN_INFO=" ${MODEL_ICON:-}${MODEL_DISPLAY} ↑$(format_tokens "$INPUT_TOKENS") ↓$(format_tokens "$OUTPUT_TOKENS")"
else
  TOKEN_INFO=" ${MODEL_ICON:-}${MODEL_DISPLAY}"
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
  COMPONENTS+=("mauve|${DEVSPACE}")
fi

# Add hostname (rosewater background)
if [[ -n "$HOSTNAME" ]]; then
  HOSTNAME_TEXT="${HOSTNAME_ICON}${HOSTNAME}"
  COMPONENTS+=("rosewater|${HOSTNAME_TEXT}")
fi

# Add git branch (sky background)
if [[ -n "$GIT_BRANCH" ]]; then
  GIT_TEXT="${GIT_ICON}${GIT_BRANCH}"
  if [[ -n "$GIT_STATUS" ]]; then
    GIT_TEXT="${GIT_TEXT} ${GIT_STATUS}"
  fi
  COMPONENTS+=("sky|${GIT_TEXT}")
fi

# Add AWS profile (peach background)
if [[ -n "$AWS_PROFILE" ]]; then
  COMPONENTS+=("peach|${AWS_ICON}${AWS_PROFILE}")
fi

# Add K8s context (teal background)
if [[ -n "$K8S_CONTEXT" ]]; then
  # Shorten common k8s context patterns
  SHORT_K8S="${K8S_CONTEXT}"
  SHORT_K8S="${SHORT_K8S#arn:aws:eks:*:*:cluster/}" # Remove AWS EKS ARN prefix
  SHORT_K8S="${SHORT_K8S#gke_*_*_}"                 # Shorten GKE contexts
  COMPONENTS+=("teal|${K8S_ICON}${SHORT_K8S}")
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
# Use printf %b to interpret the escape sequences, then strip them
# Calculate visible length for spacing - properly handle multi-byte UTF-8 characters
# Use wc -m to count display width instead of byte length
LEFT_VISIBLE=$(printf '%b' "${STATUS_LINE}" | sed 's/\x1b\[[0-9;:]*m//g')
RIGHT_VISIBLE=$(printf '%b' "${RIGHT_SIDE}" | sed 's/\x1b\[[0-9;:]*m//g')
# Use wc -m for character count (not byte count)
LEFT_LENGTH=$(echo -n "$LEFT_VISIBLE" | wc -m | tr -d ' ')
RIGHT_LENGTH=$(echo -n "$RIGHT_VISIBLE" | wc -m | tr -d ' ')

# Calculate the exact width we need to work with
# Account for newline and a larger safety margin to prevent overflow on first render
RESERVED_END_CHARS=4 # Newline + 3 char safety margin to prevent overflow
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
  if [[ $SPACE_FOR_MIDDLE -lt 2 ]]; then
    SPACE_FOR_MIDDLE=2 # Minimum spacing
  fi
  MIDDLE_SECTION=$(printf '%*s' $SPACE_FOR_MIDDLE '')
fi

# Output the statusline
time_point "before_output"
printf '%b\n' "${STATUS_LINE}${MIDDLE_SECTION}${RIGHT_SIDE}"
time_point "after_output"
