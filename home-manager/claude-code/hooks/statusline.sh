#!/usr/bin/env bash
# statusline.sh - Claude Code status line that mimics starship prompt
#
# This script generates a status line for Claude Code that matches the
# starship configuration with Catppuccin Mocha colors and chevron separators.

# Source common helpers for colors (though we'll need more specific ones)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common-helpers.sh"

# ============================================================================
# CATPPUCCIN MOCHA COLORS
# ============================================================================

# Convert hex to RGB for ANSI 256 color approximation
# Using the closest ANSI 256 colors to Catppuccin Mocha palette
LAVENDER_BG="\033[48;5;183m"   # #b4befe
LAVENDER_FG="\033[38;5;183m"
GREEN_BG="\033[48;5;150m"       # #a6e3a1
GREEN_FG="\033[38;5;150m"
RED_FG="\033[38;5;211m"         # #f38ba8
MAUVE_FG="\033[38;5;183m"       # #cba6f7
ROSEWATER_FG="\033[38;5;224m"   # #f5e0dc
SKY_FG="\033[38;5;116m"         # #89dceb
BASE_FG="\033[38;5;235m"        # #1e1e2e (dark text on colored backgrounds)
TEXT_FG="\033[38;5;189m"        # #cdd6f4 (light text)

# Chevron character - using > as fallback if powerline fonts aren't available
# You can change this to "" if you have powerline fonts installed
CHEVRON="❯"

# ============================================================================
# MAIN LOGIC
# ============================================================================

# Read JSON input from stdin
input=$(cat)

# Parse JSON values using jq
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name // "Claude"')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')

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
    DEVSPACE=" ${DEVSPACE_SYMBOL} ${TMUX_DEVSPACE}"
fi

# Format the directory
DIR_PATH=$(format_path "$CURRENT_DIR")

# Get git information
IFS='|' read -r GIT_BRANCH GIT_STATUS <<< "$(get_git_info)"

# ============================================================================
# BUILD STATUS LINE
# ============================================================================

# Start with directory (left side)
STATUS_LINE=""

# Directory with lavender background
STATUS_LINE="${LAVENDER_FG}${CHEVRON}${NC}"
STATUS_LINE="${STATUS_LINE}${LAVENDER_BG}${BASE_FG} ${DIR_PATH} ${NC}"

# Add success/error chevron (we'll default to success for now)
STATUS_LINE="${STATUS_LINE}${GREEN_BG}${LAVENDER_FG}${CHEVRON}${NC}"
STATUS_LINE="${STATUS_LINE}${GREEN_FG}${CHEVRON}${NC}"

# Add spacing
STATUS_LINE="${STATUS_LINE}  "

# Right side components
RIGHT_SIDE=""

# Add model in square brackets (simplified, no background)
RIGHT_SIDE="${RIGHT_SIDE}${TEXT_FG}[${MODEL_DISPLAY}]${NC}"

# Add devspace if present
if [[ -n "$DEVSPACE" ]]; then
    RIGHT_SIDE="${RIGHT_SIDE}  ${MAUVE_FG}${DEVSPACE}${NC}"
fi

# Add hostname
if [[ -n "$HOSTNAME" ]]; then
    RIGHT_SIDE="${RIGHT_SIDE}  ${ROSEWATER_FG}${HOSTNAME}${NC}"
fi

# Add git branch and status
if [[ -n "$GIT_BRANCH" ]]; then
    RIGHT_SIDE="${RIGHT_SIDE}  ${SKY_FG} ${GIT_BRANCH}${NC}"
    if [[ -n "$GIT_STATUS" ]]; then
        RIGHT_SIDE="${RIGHT_SIDE} ${RED_FG}${GIT_STATUS}${NC}"
    fi
fi

# Combine left and right
# Use printf to properly output ANSI escape sequences
printf '%b\n' "${STATUS_LINE}${RIGHT_SIDE}"