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
YELLOW_BG="\033[48;2;249;226;175m"      # #f9e2af (Catppuccin Mocha yellow)
YELLOW_FG="\033[38;2;249;226;175m"
PEACH_BG="\033[48;2;250;179;135m"      # #fab387
PEACH_FG="\033[38;2;250;179;135m"
TEAL_BG="\033[48;2;148;226;213m"       # #94e2d5
TEAL_FG="\033[38;2;148;226;213m"
RED_BG="\033[48;2;243;139;168m"        # #f38ba8 (Catppuccin Mocha red)
RED_FG="\033[38;2;243;139;168m"
BASE_FG="\033[38;2;30;30;46m"          # #1e1e2e (dark text on colored backgrounds)
BASE_BG="\033[48;2;88;91;112m"         # #585b70 (surface2 - space gray for progress bar background)

# Lighter background variants for progress bar empty sections (muted versions of each color)
GREEN_LIGHT_BG="\033[48;2;86;127;81m"     # Muted green (darker version of #a6e3a1)
YELLOW_LIGHT_BG="\033[48;2;149;136;95m"   # Muted yellow (darker version of #f9e2af)  
PEACH_LIGHT_BG="\033[48;2;150;107;81m"    # Muted peach (darker version of #fab387)
RED_LIGHT_BG="\033[48;2;146;83;100m"      # Muted red (darker version of #f38ba8)

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

# Context bar characters - customize these for the progress bar appearance
PROGRESS_LEFT_EMPTY=""
PROGRESS_MID_EMPTY=""
PROGRESS_RIGHT_EMPTY=""
PROGRESS_LEFT_FULL=""
PROGRESS_MID_FULL=""
PROGRESS_RIGHT_FULL=""

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
        echo "0|0|0|0"
        return
    fi
    
    local input_tokens=0
    local output_tokens=0
    local cached_tokens=0
    local context_length=0
    local most_recent_usage=""
    
    # Parse JSONL transcript for token usage
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Check if this is NOT a sidechain entry
            local is_sidechain
            is_sidechain=$(echo "$line" | jq -r '.isSidechain // false' 2>/dev/null)
            
            # Extract token counts from usage field
            local usage
            usage=$(echo "$line" | jq -r '.message.usage // empty' 2>/dev/null)
            if [[ -n "$usage" ]]; then
                input_tokens=$((input_tokens + $(echo "$usage" | jq -r '.input_tokens // 0')))
                output_tokens=$((output_tokens + $(echo "$usage" | jq -r '.output_tokens // 0')))
                # Add cache tokens
                cached_tokens=$((cached_tokens + $(echo "$usage" | jq -r '.cache_read_input_tokens // 0')))
                
                # Track most recent main chain entry for context length
                if [[ "$is_sidechain" != "true" ]]; then
                    most_recent_usage="$usage"
                fi
            fi
        fi
    done < "$transcript"
    
    # Calculate context length from most recent main chain message
    if [[ -n "$most_recent_usage" ]]; then
        local input cache_read cache_creation
        input=$(echo "$most_recent_usage" | jq -r '.input_tokens // 0')
        cache_read=$(echo "$most_recent_usage" | jq -r '.cache_read_input_tokens // 0')
        cache_creation=$(echo "$most_recent_usage" | jq -r '.cache_creation_input_tokens // 0')
        context_length=$((input + cache_read + cache_creation))
    fi
    
    echo "${input_tokens}|${output_tokens}|${cached_tokens}|${context_length}"
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

# Create context usage bar
create_context_bar() {
    local context_length=$1
    local term_width=$2
    local left_length=$3
    local right_length=$4
    
    # Calculate percentage using auto-compact threshold (160k = 80% of 200k)
    local percentage=0
    if [[ $context_length -gt 0 ]]; then
        percentage=$(echo "scale=1; $context_length * 100 / 160000" | bc)
        # Cap at 125% (200k/160k) for display
        if (( $(echo "$percentage > 125" | bc -l) )); then
            percentage="125.0"
        fi
    fi
    
    # Calculate available width for the bar (with 5 spaces padding on each side)
    local available_width=$((term_width - left_length - right_length - 10))
    
    # Minimum bar width (for "Context: XX.X%")
    local min_width=20
    if [[ $available_width -lt $min_width ]]; then
        # Not enough space for bar
        echo ""
        return
    fi
    
    # Bar components
    local label="Context: "
    local percent_text=" ${percentage}%"  # Space before percentage
    local text_length=$((${#label} + ${#percent_text} + 1))  # +1 for space after percent
    
    # Calculate bar fill width (minus curves and text)
    local bar_width=$((available_width - text_length - 2))  # -2 for curves
    if [[ $bar_width -lt 4 ]]; then
        # Too small for a meaningful bar
        echo ""
        return
    fi
    
    # Calculate filled portion (cap at 100% for display)
    local display_percentage=$percentage
    if (( $(echo "$display_percentage > 100" | bc -l) )); then
        display_percentage=100
    fi
    local filled_width
    filled_width=$(echo "scale=0; $bar_width * $display_percentage / 100" | bc)
    filled_width=${filled_width%.*}  # Remove decimal part
    
    # Choose colors based on percentage
    local bg_color fg_color fg_light_bg
    if (( $(echo "$percentage < 50" | bc -l) )); then
        # Green - plenty of space
        bg_color="${GREEN_BG}"
        fg_color="${GREEN_FG}"
        fg_light_bg="${GREEN_LIGHT_BG}"
    elif (( $(echo "$percentage < 75" | bc -l) )); then
        # Yellow - getting full
        bg_color="${YELLOW_BG}"
        fg_color="${YELLOW_FG}"
        fg_light_bg="${YELLOW_LIGHT_BG}"
    elif (( $(echo "$percentage < 100" | bc -l) )); then
        # Peach - approaching auto-compact
        bg_color="${PEACH_BG}"
        fg_color="${PEACH_FG}"
        fg_light_bg="${PEACH_LIGHT_BG}"
    else
        # Red - auto-compact imminent or triggered
        bg_color="${RED_BG}"
        fg_color="${RED_FG}"
        fg_light_bg="${RED_LIGHT_BG}"
    fi
    
    # Create bar with Nerd Font progress characters
    # Filled sections: progress color foreground on space gray background
    # Unfilled sections: progress color foreground on muted progress color background
    local bar=""
    local i
    for ((i=0; i<bar_width; i++)); do
        local char=""
        local section=""
        
        # Determine which character to use based on position and fill status
        if [[ $i -eq 0 ]]; then
            # Left edge
            if [[ $i -lt $filled_width ]]; then
                char="${PROGRESS_LEFT_FULL}"
                # Filled: fg color on space gray bg
                section="${BASE_BG}${fg_color}${char}${NC}"
            else
                char="${PROGRESS_LEFT_EMPTY}"
                # Unfilled: fg color on muted bg
                section="${fg_light_bg}${fg_color}${char}${NC}"
            fi
        elif [[ $i -eq $((bar_width - 1)) ]]; then
            # Right edge
            if [[ $i -lt $filled_width ]]; then
                char="${PROGRESS_RIGHT_FULL}"
                # Filled: fg color on space gray bg
                section="${BASE_BG}${fg_color}${char}${NC}"
            else
                char="${PROGRESS_RIGHT_EMPTY}"
                # Unfilled: fg color on muted bg
                section="${fg_light_bg}${fg_color}${char}${NC}"
            fi
        else
            # Middle sections
            if [[ $i -lt $filled_width ]]; then
                char="${PROGRESS_MID_FULL}"
                # Filled: fg color on space gray bg
                section="${BASE_BG}${fg_color}${char}${NC}"
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

# Get terminal width - we'll adjust it later based on context percentage
RAW_TERM_WIDTH=$(get_terminal_width)

# Get token metrics early so we can use context percentage for width calculation
IFS='|' read -r INPUT_TOKENS OUTPUT_TOKENS _ CONTEXT_LENGTH <<< "$(get_token_metrics "$TRANSCRIPT_PATH")"

# Calculate adjusted terminal width based on context percentage (full-until-compact mode)
TERM_WIDTH=$RAW_TERM_WIDTH
if [[ $RAW_TERM_WIDTH -gt 0 ]]; then
    # Calculate context percentage using auto-compact threshold (160k = 80% of 200k)
    if [[ $CONTEXT_LENGTH -gt 0 ]]; then
        CONTEXT_PERCENTAGE=$(echo "scale=1; $CONTEXT_LENGTH * 100 / 160000" | bc)
        # If context is above 60% of the auto-compact threshold, start reserving space
        if (( $(echo "$CONTEXT_PERCENTAGE >= 60" | bc -l) )); then
            # Reserve 42 characters for auto-compact message when context is high
            # (41 for message + 1 for the space we add after right curve)
            if [[ $RAW_TERM_WIDTH -gt 42 ]]; then
                TERM_WIDTH=$((RAW_TERM_WIDTH - 42))
            fi
        else
            # Use full width minus small padding when context is low
            if [[ $RAW_TERM_WIDTH -gt 4 ]]; then
                TERM_WIDTH=$((RAW_TERM_WIDTH - 4))
            fi
        fi
    else
        # No context data, use full width minus small padding
        if [[ $RAW_TERM_WIDTH -gt 4 ]]; then
            TERM_WIDTH=$((RAW_TERM_WIDTH - 4))
        fi
    fi
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

# Calculate spacing to push right side to the right
# Use printf %b to interpret the escape sequences, then strip them
# Calculate visible length for spacing - properly handle multi-byte UTF-8 characters
# Use wc -m to count display width instead of byte length  
LEFT_VISIBLE=$(printf '%b' "${STATUS_LINE}" | sed 's/\x1b\[[0-9;:]*m//g')
RIGHT_VISIBLE=$(printf '%b' "${RIGHT_SIDE}" | sed 's/\x1b\[[0-9;:]*m//g')
# Use wc -m for character count (not byte count)
LEFT_LENGTH=$(echo -n "$LEFT_VISIBLE" | wc -m | tr -d ' ')
RIGHT_LENGTH=$(echo -n "$RIGHT_VISIBLE" | wc -m | tr -d ' ')

# Create context bar if we have enough space and context data
CONTEXT_BAR=""
if [[ $TERM_WIDTH -gt 0 ]] && [[ $CONTEXT_LENGTH -gt 0 ]]; then
    CONTEXT_BAR=$(create_context_bar "$CONTEXT_LENGTH" "$TERM_WIDTH" "$LEFT_LENGTH" "$RIGHT_LENGTH")
fi

# Calculate middle section (context bar or spacing)
if [[ -n "$CONTEXT_BAR" ]]; then
    # Use context bar as the middle section with small padding
    MIDDLE_SECTION="     ${CONTEXT_BAR}     "
else
    # No context bar, calculate regular spacing
    TOTAL_LENGTH=$((LEFT_LENGTH + RIGHT_LENGTH))
    SPACES=2  # Minimum spacing
    if [[ $TERM_WIDTH -gt 0 ]] && [[ $TOTAL_LENGTH -lt $TERM_WIDTH ]]; then
        # Calculate available space
        AVAILABLE=$((TERM_WIDTH - TOTAL_LENGTH - 1))  # -1 for the newline
        if [[ $AVAILABLE -gt 2 ]]; then
            SPACES=$AVAILABLE
        fi
    fi
    MIDDLE_SECTION=$(printf '%*s' $SPACES '')
fi

# Add right curve at the end
if [[ -n "$RIGHT_SIDE" ]]; then
    # Get the last color used
    if [[ -n "$PREV_COLOR" ]]; then
        # Check if we're in compact mode (context >= 60% of auto-compact threshold)
        IN_COMPACT_MODE=0
        if [[ $CONTEXT_LENGTH -gt 0 ]]; then
            COMPACT_CHECK_PERCENTAGE=$(echo "scale=1; $CONTEXT_LENGTH * 100 / 160000" | bc)
            if (( $(echo "$COMPACT_CHECK_PERCENTAGE >= 60" | bc -l) )); then
                IN_COMPACT_MODE=1
            fi
        fi
        
        # Add right curve with optional space for compact mode
        CURVE_SUFFIX=""
        if [[ $IN_COMPACT_MODE -eq 1 ]]; then
            CURVE_SUFFIX=" "  # Add space in compact mode for auto-compact message
        fi
        
        case $PREV_COLOR in
            mauve) RIGHT_SIDE="${RIGHT_SIDE}${MAUVE_FG}${RIGHT_CURVE}${NC}${CURVE_SUFFIX}" ;;
            rosewater) RIGHT_SIDE="${RIGHT_SIDE}${ROSEWATER_FG}${RIGHT_CURVE}${NC}${CURVE_SUFFIX}" ;;
            sky) RIGHT_SIDE="${RIGHT_SIDE}${SKY_FG}${RIGHT_CURVE}${NC}${CURVE_SUFFIX}" ;;
            peach) RIGHT_SIDE="${RIGHT_SIDE}${PEACH_FG}${RIGHT_CURVE}${NC}${CURVE_SUFFIX}" ;;
            teal) RIGHT_SIDE="${RIGHT_SIDE}${TEAL_FG}${RIGHT_CURVE}${NC}${CURVE_SUFFIX}" ;;
        esac
    fi
fi

# Combine left and right with middle section (context bar or spacing)
# Use printf to properly output ANSI escape sequences
printf '%b\n' "${STATUS_LINE}${MIDDLE_SECTION}${RIGHT_SIDE}"
