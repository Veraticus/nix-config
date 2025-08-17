#!/usr/bin/env bash
# statusline.sh - Claude Code status line that mimics starship prompt
#
# This script generates a status line for Claude Code that matches the
# starship configuration with Catppuccin Mocha colors and powerline separators.

# Source common helpers for colors (though we'll need more specific ones)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common-helpers.sh"

# ============================================================================
# CATPPUCCIN MOCHA COLORS - True color (24-bit) support
# ============================================================================

# Using true color escape sequences for exact Catppuccin Mocha colors
LAVENDER_BG="\033[48;2;180;190;254m"   # #b4befe
LAVENDER_FG="\033[38;2;180;190;254m"
GREEN_BG="\033[48;2;166;227;161m"      # #a6e3a1
GREEN_FG="\033[38;2;166;227;161m"
MAUVE_BG="\033[48;2;203;166;247m"      # #cba6f7
MAUVE_FG="\033[38;2;203;166;247m"
ROSEWATER_BG="\033[48;2;245;224;220m"  # #f5e0dc
ROSEWATER_FG="\033[38;2;245;224;220m"
SKY_BG="\033[48;2;137;220;235m"        # #89dceb
SKY_FG="\033[38;2;137;220;235m"
PEACH_BG="\033[48;2;250;179;135m"      # #fab387
PEACH_FG="\033[38;2;250;179;135m"
TEAL_BG="\033[48;2;148;226;213m"       # #94e2d5
TEAL_FG="\033[38;2;148;226;213m"
BASE_FG="\033[38;2;30;30;46m"          # #1e1e2e (dark text on colored backgrounds)

# Powerline characters
LEFT_CHEVRON=""
LEFT_CURVE=""
RIGHT_CURVE=""
RIGHT_CHEVRON=""

# Icons for different sections (customize as needed)
GIT_ICON="  "
AWS_ICON="  "
K8S_ICON=" ☸ "
DEVSPACE_ICON=""  # Will be set based on devspace name
HOSTNAME_ICON="  " 
MODEL_ICONS="󰚩󱚝󱚟󱚡󱚣󱚥"

# ============================================================================
# MAIN LOGIC
# ============================================================================

# Read JSON input from stdin
input=$(cat)

# Parse JSON values using jq
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name // "Claude"')

# Select a random icon from MODEL_ICONS
ICON_COUNT=${#MODEL_ICONS}
RANDOM_INDEX=$((RANDOM % ICON_COUNT))
MODEL_ICON="${MODEL_ICONS:$RANDOM_INDEX:1} "
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // ""')

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
    read -ra PARTS <<< "$path"
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

# Get git information if in a git repo
get_git_info() {
    local git_branch=""
    local git_status=""
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Get current branch
        git_branch=$(git branch --show-current 2>/dev/null || echo "")
        
        # Get git status indicators
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            git_status="!"
        fi
    fi
    
    echo "${git_branch}|${git_status}"
}

# Get hostname (short form)
HOSTNAME=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "unknown")

# Check if we're in tmux and get devspace
DEVSPACE=""
DEVSPACE_SYMBOL=""
# Check for TMUX_DEVSPACE environment variable (it might be set even outside tmux)
if [[ -n "${TMUX_DEVSPACE:-}" ]] && [[ "${TMUX_DEVSPACE}" != "-TMUX_DEVSPACE" ]]; then
    case "$TMUX_DEVSPACE" in
        mercury) DEVSPACE_SYMBOL="☿" ;;
        venus)   DEVSPACE_SYMBOL="♀" ;;
        earth)   DEVSPACE_SYMBOL="♁" ;;
        mars)    DEVSPACE_SYMBOL="♂" ;;
        jupiter) DEVSPACE_SYMBOL="♃" ;;
        *)       DEVSPACE_SYMBOL="●" ;;
    esac
    DEVSPACE_ICON="${DEVSPACE_SYMBOL}"  # Use the planet symbol as the icon
    DEVSPACE=" ${DEVSPACE_ICON} ${TMUX_DEVSPACE}"
fi

# Format the directory
DIR_PATH=$(format_path "$CURRENT_DIR")

# Get git information
IFS='|' read -r GIT_BRANCH GIT_STATUS <<< "$(get_git_info)"

# Get token metrics if transcript is available
get_token_metrics() {
    local transcript="$1"
    if [[ -z "$transcript" ]] || [[ ! -f "$transcript" ]]; then
        echo "0|0|0"
        return
    fi
    
    local input_tokens=0
    local output_tokens=0
    local cached_tokens=0
    
    # Parse JSONL transcript for token usage
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract token counts from usage field
            local usage
            usage=$(echo "$line" | jq -r '.message.usage // empty' 2>/dev/null)
            if [[ -n "$usage" ]]; then
                input_tokens=$((input_tokens + $(echo "$usage" | jq -r '.input_tokens // 0')))
                output_tokens=$((output_tokens + $(echo "$usage" | jq -r '.output_tokens // 0')))
                # Add cache tokens
                cached_tokens=$((cached_tokens + $(echo "$usage" | jq -r '.cache_read_input_tokens // 0')))
            fi
        fi
    done < "$transcript"
    
    echo "${input_tokens}|${output_tokens}|${cached_tokens}"
}

# Format token count for display
format_tokens() {
    local count=$1
    if [[ $count -ge 1000000 ]]; then
        printf "%.1fM" "$(echo "scale=1; $count / 1000000" | bc)"
    elif [[ $count -ge 1000 ]]; then
        printf "%.1fk" "$(echo "scale=1; $count / 1000" | bc)"
    else
        echo "$count"
    fi
}

# Get token metrics
IFS='|' read -r INPUT_TOKENS OUTPUT_TOKENS _ <<< "$(get_token_metrics "$TRANSCRIPT_PATH")"

# Use full model name (no shortening)

# ============================================================================
# BUILD STATUS LINE
# ============================================================================

# Calculate terminal width for right-alignment
get_terminal_width() {
    local width=0  # Default to 0 to disable spacing if we can't detect
    
    # Try environment variable first (if set explicitly)
    if [[ -n "${COLUMNS:-}" ]]; then
        width=$COLUMNS
        echo "$width"
        return
    fi
    
    # Search up the process tree for a TTY (up to 5 levels)
    local search_pid=$PPID
    local tty
    
    for _ in 1 2 3 4 5; do
        tty=$(ps -o tty= -p "$search_pid" 2>/dev/null | tr -d ' ')
        
        if [[ -n "$tty" ]] && [[ "$tty" != "??" ]] && [[ "$tty" != "?" ]]; then
            # Found a TTY, try to get its size
            if [[ -e "/dev/$tty" ]]; then
                local stty_output
                stty_output=$(stty size < "/dev/$tty" 2>/dev/null || true)
                if [[ -n "$stty_output" ]]; then
                    width=$(echo "$stty_output" | awk '{print $2}')
                    if [[ -n "$width" ]] && [[ "$width" -gt 0 ]]; then
                        echo "$width"
                        return
                    fi
                fi
            fi
        fi
        
        # Get parent of current search_pid
        search_pid=$(ps -o ppid= -p "$search_pid" 2>/dev/null | tr -d ' ')
        if [[ -z "$search_pid" ]] || [[ "$search_pid" == "1" ]]; then
            break
        fi
    done
    
    # Fallback: try tput cols
    if command -v tput >/dev/null 2>&1; then
        local tput_width
        tput_width=$(tput cols 2>/dev/null)
        if [[ -n "$tput_width" ]] && [[ "$tput_width" -gt 0 ]]; then
            width=$tput_width
        fi
    fi
    
    # If still no width, try a default based on common terminal sizes
    if [[ $width -eq 0 ]]; then
        width=80  # Common default
    fi
    
    echo "$width"
}

# Get terminal width and subtract 40 for auto-compact message
RAW_TERM_WIDTH=$(get_terminal_width)
# Reserve 40 characters for "Context left until auto-compact: X%" message
if [[ $RAW_TERM_WIDTH -gt 40 ]]; then
    TERM_WIDTH=$((RAW_TERM_WIDTH - 40))
else
    TERM_WIDTH=$RAW_TERM_WIDTH
fi

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

# Add model/tokens section with green background
STATUS_LINE="${STATUS_LINE}${GREEN_BG}${LAVENDER_FG}${LEFT_CHEVRON}${NC}"

# Show model name and token usage
TOKEN_INFO=""
if [[ $INPUT_TOKENS -gt 0 ]] || [[ $OUTPUT_TOKENS -gt 0 ]]; then
    TOKEN_INFO=" ${MODEL_ICON:-}${MODEL_DISPLAY} ↑$(format_tokens "$INPUT_TOKENS") ↓$(format_tokens "$OUTPUT_TOKENS")"
else
    TOKEN_INFO=" ${MODEL_ICON:-}${MODEL_DISPLAY}"
fi
STATUS_LINE="${STATUS_LINE}${GREEN_BG}${BASE_FG}${TOKEN_INFO} ${NC}"

# End the left section
STATUS_LINE="${STATUS_LINE}${GREEN_FG}${LEFT_CHEVRON}${NC}"

# Build right side with powerline progression
RIGHT_SIDE=""

# Check for AWS profile (remove "export AWS_PROFILE=" prefix if present)
AWS_PROFILE="${AWS_PROFILE:-}"
AWS_PROFILE="${AWS_PROFILE#export AWS_PROFILE=}"

# Check for Kubernetes context
K8S_CONTEXT=""
if command -v kubectl >/dev/null 2>&1; then
    K8S_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
fi

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
    SHORT_K8S="${SHORT_K8S#arn:aws:eks:*:*:cluster/}"  # Remove AWS EKS ARN prefix
    SHORT_K8S="${SHORT_K8S#gke_*_*_}"  # Shorten GKE contexts
    COMPONENTS+=("teal|${K8S_ICON}${SHORT_K8S}")
fi

# Build the right side with powerline separators
PREV_COLOR=""
for component in "${COMPONENTS[@]}"; do
    IFS='|' read -r COLOR TEXT <<< "$component"
    
    # Add separator from previous color
    if [[ -n "$PREV_COLOR" ]]; then
        case $PREV_COLOR in
            mauve) RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_BG}${MAUVE_FG}${RIGHT_CHEVRON}${NC}" ;;
            rosewater) 
                if [[ "$COLOR" == "sky" ]]; then
                    RIGHT_SIDE="${RIGHT_SIDE}${SKY_BG}${ROSEWATER_FG}${RIGHT_CHEVRON}${NC}"
                elif [[ "$COLOR" == "peach" ]]; then
                    RIGHT_SIDE="${RIGHT_SIDE}${PEACH_BG}${ROSEWATER_FG}${RIGHT_CHEVRON}${NC}"
                elif [[ "$COLOR" == "teal" ]]; then
                    RIGHT_SIDE="${RIGHT_SIDE}${TEAL_BG}${ROSEWATER_FG}${RIGHT_CHEVRON}${NC}"
                fi
                ;;
            sky) 
                if [[ "$COLOR" == "peach" ]]; then
                    RIGHT_SIDE="${RIGHT_SIDE}${PEACH_BG}${SKY_FG}${RIGHT_CHEVRON}${NC}"
                elif [[ "$COLOR" == "teal" ]]; then
                    RIGHT_SIDE="${RIGHT_SIDE}${TEAL_BG}${SKY_FG}${RIGHT_CHEVRON}${NC}"
                fi
                ;;
            peach) RIGHT_SIDE="${RIGHT_SIDE}${TEAL_BG}${PEACH_FG}${RIGHT_CHEVRON}${NC}" ;;
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

# Calculate spacing to push right side to the right
# Use printf %b to interpret the escape sequences, then strip them
LEFT_VISIBLE=$(printf '%b' "${STATUS_LINE}" | sed $'s/\033\\[[0-9;:]*m//g' | sed $'s/[\uE0B0-\uE0B7]//g')
RIGHT_VISIBLE=$(printf '%b' "${RIGHT_SIDE}" | sed $'s/\033\\[[0-9;:]*m//g' | sed $'s/[\uE0B0-\uE0B7]//g')
LEFT_LENGTH=${#LEFT_VISIBLE}
RIGHT_LENGTH=${#RIGHT_VISIBLE}
TOTAL_LENGTH=$((LEFT_LENGTH + RIGHT_LENGTH))

# Add spacing between left and right
# Always use at least 2 spaces, expand if terminal is wider
SPACES=2  # Minimum spacing
if [[ $TERM_WIDTH -gt 0 ]] && [[ $TOTAL_LENGTH -lt $TERM_WIDTH ]]; then
    # Calculate available space
    AVAILABLE=$((TERM_WIDTH - TOTAL_LENGTH - 1))  # -1 for the newline
    if [[ $AVAILABLE -gt 2 ]]; then
        SPACES=$AVAILABLE
    fi
fi
SPACING=$(printf '%*s' $SPACES '')

# Add right curve at the end
if [[ -n "$RIGHT_SIDE" ]]; then
    # Get the last color used
    if [[ -n "$PREV_COLOR" ]]; then
        case $PREV_COLOR in
            mauve) RIGHT_SIDE="${RIGHT_SIDE}${MAUVE_FG}${RIGHT_CURVE}${NC}" ;;
            rosewater) RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_FG}${RIGHT_CURVE}${NC}" ;;
            sky) RIGHT_SIDE="${RIGHT_SIDE}${SKY_FG}${RIGHT_CURVE}${NC}" ;;
            peach) RIGHT_SIDE="${RIGHT_SIDE}${PEACH_FG}${RIGHT_CURVE}${NC}" ;;
            teal) RIGHT_SIDE="${RIGHT_SIDE}${TEAL_FG}${RIGHT_CURVE}${NC}" ;;
        esac
    fi
fi

# Combine left and right with spacing
# Use printf to properly output ANSI escape sequences
printf '%b\n' "${STATUS_LINE}${SPACING}${RIGHT_SIDE}"
