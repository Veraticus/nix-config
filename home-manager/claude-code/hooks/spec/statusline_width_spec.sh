#!/usr/bin/env bash

# Comprehensive test suite for statusline width consistency

# Constants for testing - defined globally for ShellSpec
TERMINAL_WIDTH=214         # Terminal width we're testing with
EXPECTED_WIDTH=210         # Should be TERMINAL_WIDTH - 4 (RESERVED_END_CHARS)
EXPECTED_WIDTH_COMPACT=169 # In compact mode: TERMINAL_WIDTH - 4 - 41

Describe 'Statusline width validation'

setup() {
  TEMP_DIR=$(create_test_dir)
  cd "$TEMP_DIR" || return

  # Create a mock transcript with varying token amounts
  mkdir -p "$TEMP_DIR/.claude/projects/-Users-joshsymonds-Personal-nix-config"

  # Use a test-specific cache directory to avoid polluting real cache
  export CLAUDE_STATUSLINE_CACHE_DIR="$TEMP_DIR/.cache"
  mkdir -p "$CLAUDE_STATUSLINE_CACHE_DIR"
  
  # Set test-specific kubeconfig that doesn't exist by default
  export CLAUDE_STATUSLINE_KUBECONFIG="$TEMP_DIR/.kube/config"
  
  # Ensure devspace is not set by default
  export CLAUDE_STATUSLINE_DEVSPACE=""
  
  # Default hostname override (will be overridden per test)
  export CLAUDE_STATUSLINE_HOSTNAME=""

  # Export the constants for the test functions
  export TERMINAL_WIDTH=214
  export EXPECTED_WIDTH=210
  export EXPECTED_WIDTH_COMPACT=169
}

cleanup() {
  cd "$SPEC_DIR" || return
  rm -rf "$TEMP_DIR"
  rm -rf "$TEMP_DIR/.claude/projects/-Users-joshsymonds-Personal-nix-config/test_*.jsonl"
  
  # Unset test environment variables
  unset CLAUDE_STATUSLINE_CACHE_DIR
  unset CLAUDE_STATUSLINE_KUBECONFIG
  unset CLAUDE_STATUSLINE_DEVSPACE
  unset CLAUDE_STATUSLINE_HOSTNAME
}

BeforeEach 'setup'
AfterEach 'cleanup'

create_transcript() {
  local input_tokens="$1"
  local output_tokens="$2"
  local context_tokens="$3"
  local transcript_file="$TEMP_DIR/.claude/projects/-Users-joshsymonds-Personal-nix-config/test_transcript.jsonl"

  # The statusline:
  # - Sums input_tokens across ALL messages for display
  # - Sums output_tokens across ALL messages for display
  # - Uses ONLY the LAST message's (input + cache_read + cache_creation) for context
  # So we create two messages: first has the bulk tokens, last has just the context
  cat >"$transcript_file" <<EOF
{"message":{"usage":{"input_tokens":$input_tokens,"output_tokens":$output_tokens,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"usage":{"input_tokens":0,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":$context_tokens}}}
EOF
  echo "$transcript_file"
}

test_statusline_width() {
  local model="$1"
  local dir="$2"
  local hostname="$3"
  local git_branch="$4"
  local aws_profile="$5"
  local k8s_context="$6"
  local input_tokens="$7"
  local output_tokens="$8"
  local context_tokens="$9"

  # Create a unique cache directory for this specific test
  local test_cache_dir="$TEMP_DIR/.cache.$$.$RANDOM"
  mkdir -p "$test_cache_dir"
  export CLAUDE_STATUSLINE_CACHE_DIR="$test_cache_dir"

  # Create transcript with specified tokens
  local transcript
  transcript=$(create_transcript "$input_tokens" "$output_tokens" "$context_tokens")

  # Setup environment
  if [[ -n "$git_branch" ]]; then
    git init >/dev/null 2>&1 || true
    git checkout -b "$git_branch" >/dev/null 2>&1 || true
    echo "test" >test_file
  fi

  # Build JSON input
  local json_input
  json_input=$(
    cat <<EOF
{
  "model": {"display_name": "$model"},
  "workspace": {"project_dir": "$dir"},
  "transcript_path": "$transcript"
}
EOF
  )

  # Run statusline with fixed terminal width
  export COLUMNS=$TERMINAL_WIDTH
  export CLAUDE_STATUSLINE_HOSTNAME="$hostname"
  export AWS_PROFILE="$aws_profile"
  export CLAUDE_STATUSLINE_DEVSPACE=""  # Explicitly disable devspace unless overridden

  # Create a temporary kubeconfig if k8s context is specified
  if [[ -n "$k8s_context" ]]; then
    # Create a minimal kubeconfig file with the specified context
    mkdir -p "$TEMP_DIR/.kube"
    cat > "$TEMP_DIR/.kube/config" <<EOF
apiVersion: v1
kind: Config
current-context: $k8s_context
contexts:
- context:
    cluster: test-cluster
    user: test-user
  name: $k8s_context
EOF
    export CLAUDE_STATUSLINE_KUBECONFIG="$TEMP_DIR/.kube/config"
  else
    # No k8s context - point to non-existent file so nothing is found
    export CLAUDE_STATUSLINE_KUBECONFIG="/dev/null"
  fi

  # Run the statusline and capture output
  local output
  output=$(echo "$json_input" | bash "$HOOK_DIR/statusline.sh" 2>/dev/null)

  # If output is empty, there was an error - try to get error message
  if [[ -z "$output" ]]; then
    # Debug: try running with errors visible
    local error_output
    error_output=$(echo "$json_input" | bash "$HOOK_DIR/statusline.sh" 2>&1)
    >&2 echo "DEBUG: Statusline returned no output. Error was: $error_output"
    echo "0"
    return
  fi

  # Remove ANSI codes and get visible length
  # Using sed here as bash parameter expansion doesn't handle complex regex well
  local visible_output
  # shellcheck disable=SC2001
  visible_output=$(echo "$output" | sed 's/\x1b\[[0-9;:]*m//g')

  # Count characters first
  local char_count
  char_count=$(echo -n "$visible_output" | wc -m | tr -d ' ')

  # Count wide characters (Nerd Font icons that display as 2 columns)
  # These are the icons we use that are double-width:
  # 󱚟 󱚥 󱚣 󱚦 󱚢 󱚡 (model icons)
  #  (git icon)
  #  (AWS icon)
  # ☸ (k8s icon)
  #  (hostname icon - U+F233)
  # ☿ ♁ ♀ ♂ ♃ ♄ ♅ ♆ (planet symbols for devspace)
  local wide_char_count=0

  # Count each wide character in the output
  # Model icons (these are 4-byte UTF-8 sequences)
  for icon in "󱚟" "󱚥" "󱚣" "󱚦" "󱚢" "󱚡"; do
    local count
    count=$(echo -n "$visible_output" | grep -o "$icon" | wc -l | tr -d ' ')
    wide_char_count=$((wide_char_count + count))
  done

  # Other wide icons (3-byte UTF-8)
  # Note:  is the actual hostname icon used (U+F233), not  (U+F015)
  for icon in "" "" "" "☸" "☿" "♁" "♀" "♂" "♃" "♄" "♅" "♆"; do
    local count
    count=$(echo -n "$visible_output" | grep -o "$icon" | wc -l | tr -d ' ')
    wide_char_count=$((wide_char_count + count))
  done

  # Display width = character count + extra columns for wide chars
  local display_width=$((char_count + wide_char_count))

  # Debug output if requested
  if [[ "${DEBUG_WIDTH_TEST:-}" == "1" ]]; then
    >&2 echo "DEBUG: char_count=$char_count, wide_char_count=$wide_char_count, display_width=$display_width"
  fi
  
  # Clean up test-specific cache directory
  rm -rf "$test_cache_dir"

  # Return display width for verification
  echo "$display_width"
}

# ============================================================================
# MODEL NAME VARIATIONS
# ============================================================================

Describe 'Model name variations'
It 'handles 1-char model name'
When call test_statusline_width "C" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles short model name'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles medium model name'
When call test_statusline_width "Claude 3.5 Sonnet" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles long model name'
When call test_statusline_width "Claude 3.5 Sonnet (October 2024 Release)" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles very long model name'
When call test_statusline_width "Claude 3.5 Sonnet Latest Extended Version With Additional Features" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# HOSTNAME VARIATIONS
# ============================================================================

Describe 'Hostname variations'
It 'handles 1-char hostname'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "a" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles short hostname'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "mac" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles medium hostname'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "workstation" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles long hostname'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "development-workstation-01" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles very long hostname'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "very-long-hostname-for-testing-purposes-that-should-be-truncated" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# DIRECTORY PATH VARIATIONS
# ============================================================================

Describe 'Directory path variations'
It 'handles home directory'
When call test_statusline_width "Claude" "~" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles short path'
When call test_statusline_width "Claude" "$TEMP_DIR/work" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles medium path'
When call test_statusline_width "Claude" "$TEMP_DIR/projects/myapp/src" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles long path'
When call test_statusline_width "Claude" "$TEMP_DIR/development/projects/company/application/backend/src/main" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles very long path'
When call test_statusline_width "Claude" "$TEMP_DIR/very/deeply/nested/directory/structure/for/testing/truncation/behavior/in/statusline" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# GIT BRANCH VARIATIONS
# ============================================================================

Describe 'Git branch variations'
It 'handles no git branch'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles 1-char branch'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "m" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles short branch'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "main" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles medium branch'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "feature/new-feature" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles long branch'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "feature/JIRA-12345-implement-new-authentication-system" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles very long branch'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "feature/TICKET-99999-extremely-long-branch-name-with-many-details-that-should-definitely-be-truncated" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# AWS PROFILE VARIATIONS
# ============================================================================

Describe 'AWS profile variations'
It 'handles no AWS profile'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles 1-char AWS profile'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "p" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles short AWS profile'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "dev" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles medium AWS profile'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "development-account" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles long AWS profile'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "company-production-primary-account" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles very long AWS profile'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "organization-production-primary-account-with-very-long-name-for-testing" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# KUBERNETES CONTEXT VARIATIONS
# ============================================================================

Describe 'Kubernetes context variations'
It 'handles no k8s context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles 1-char k8s context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "k" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles short k8s context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "local" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles medium k8s context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "staging-cluster-01" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles long k8s context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "production-kubernetes-cluster-us-west-2" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles AWS EKS ARN context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "arn:aws:eks:us-west-2:123456789012:cluster/production" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles very long AWS EKS ARN'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "arn:aws:eks:eu-central-1:999888777666:cluster/production-primary-kubernetes-cluster-extended-name" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles GKE context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "gke_my-project_us-central1-a_cluster-name" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles very long GKE context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "gke_very-long-project-name-123456_us-central1-a_production-kubernetes-cluster-name-v2" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# TOKEN COUNT VARIATIONS
# ============================================================================

Describe 'Token count variations'
It 'handles zero tokens'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles small token counts'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "10" "5" "100"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles hundreds of tokens'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "500" "250" "1000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles thousands of tokens'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "5000" "2500" "10000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles tens of thousands'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "50000" "25000" "75000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles hundreds of thousands'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "500000" "250000" "100000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles millions of tokens'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "5000000" "2500000" "50000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles max display values (99.9M)'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "99999999" "99999999" "100000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles context at 127k (just below compact)'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "500000" "250000" "127999"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles context at 128k (compact threshold)'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "500000" "250000" "128000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End

It 'handles context at 160k'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "500000" "250000" "160000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End

It 'handles context at 200k (max)'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "" "500000" "250000" "200000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End
End

# ============================================================================
# COMPLEX COMBINATIONS
# ============================================================================

Describe 'Complex combinations'
It 'handles all short components'
When call test_statusline_width \
  "C" \
  "~" \
  "h" \
  "m" \
  "d" \
  "k" \
  "1" \
  "1" \
  "1"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles all medium components'
When call test_statusline_width \
  "Claude 3.5" \
  "$TEMP_DIR/projects/app" \
  "workstation" \
  "feature/task" \
  "dev-account" \
  "staging-cluster" \
  "50000" \
  "25000" \
  "75000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles all long components'
When call test_statusline_width \
  "Claude 3.5 Sonnet October Release" \
  "$TEMP_DIR/dev/projects/company/application/src" \
  "development-workstation-01" \
  "feature/JIRA-12345-new-feature" \
  "company-production-account" \
  "arn:aws:eks:us-west-2:123456789012:cluster/prod" \
  "999999" \
  "500000" \
  "100000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles all very long components'
When call test_statusline_width \
  "Claude 3.5 Sonnet Latest Extended Version With All Features Enabled" \
  "$TEMP_DIR/very/deeply/nested/directory/structure/for/testing/truncation" \
  "extremely-long-hostname-for-comprehensive-testing" \
  "feature/TICKET-99999-extremely-long-branch-name-with-many-details" \
  "organization-production-primary-account-extended-name" \
  "arn:aws:eks:eu-central-1:999888777666:cluster/production-primary-kubernetes-cluster" \
  "99999999" \
  "99999999" \
  "127999"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles mix of short and long components 1'
When call test_statusline_width \
  "Claude" \
  "$TEMP_DIR/very/deeply/nested/directory/structure" \
  "h" \
  "feature/JIRA-12345-long-branch-name" \
  "production-aws-account" \
  "k" \
  "999999" \
  "1" \
  "50000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles mix of short and long components 2'
When call test_statusline_width \
  "Claude 3.5 Sonnet Extended Version" \
  "~" \
  "very-long-hostname-testing" \
  "m" \
  "p" \
  "arn:aws:eks:us-west-2:123456789012:cluster/production-cluster" \
  "1" \
  "999999" \
  "100000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles tmux devspace with short components'
export CLAUDE_STATUSLINE_DEVSPACE="mars"
When call test_statusline_width "C" "~" "h" "m" "d" "k" "1" "1" "1"
The output should equal "$EXPECTED_WIDTH"
export CLAUDE_STATUSLINE_DEVSPACE=""
End

It 'handles tmux devspace with long components'
export CLAUDE_STATUSLINE_DEVSPACE="jupiter"
When call test_statusline_width \
  "Claude 3.5 Sonnet Extended" \
  "$TEMP_DIR/projects/application/backend" \
  "development-server" \
  "feature/new-feature" \
  "staging-account" \
  "staging-k8s-cluster" \
  "500000" \
  "250000" \
  "100000"
The output should equal "$EXPECTED_WIDTH"
export CLAUDE_STATUSLINE_DEVSPACE=""
End

It 'handles unicode paths with short components'
When call test_statusline_width "C" "$TEMP_DIR/项目" "h" "m" "" "" "1" "1" "1"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles unicode paths with long components'
When call test_statusline_width \
  "Claude 3.5 Sonnet" \
  "$TEMP_DIR/プロジェクト/アプリケーション/ソース" \
  "開発サーバー" \
  "feature/新機能" \
  "production" \
  "prod-cluster" \
  "100000" \
  "50000" \
  "75000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles edge case all empty except hostname'
When call test_statusline_width "" "$TEMP_DIR/project" "hostname" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles edge case only git branch'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "feature/only-git-branch-present" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles edge case only AWS profile'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "only-aws-profile-present" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles edge case only k8s context'
When call test_statusline_width "Claude" "$TEMP_DIR/project" "host" "" "" "only-k8s-context-present" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# COMPACT MODE COMBINATIONS
# ============================================================================

Describe 'Compact mode combinations'
It 'handles compact with all short'
When call test_statusline_width "C" "~" "h" "m" "d" "k" "1" "1" "150000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End

It 'handles compact with all medium'
When call test_statusline_width \
  "Claude 3.5" \
  "$TEMP_DIR/projects/app" \
  "workstation" \
  "feature/task" \
  "dev-account" \
  "staging-cluster" \
  "500000" \
  "250000" \
  "160000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End

It 'handles compact with all long'
When call test_statusline_width \
  "Claude 3.5 Sonnet October" \
  "$TEMP_DIR/dev/projects/company/app" \
  "development-workstation" \
  "feature/JIRA-12345-feature" \
  "company-production-account" \
  "arn:aws:eks:us-west-2:123456789012:cluster/prod" \
  "999999" \
  "500000" \
  "180000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End

It 'handles compact with all very long'
When call test_statusline_width \
  "Claude 3.5 Sonnet Latest Extended Version" \
  "$TEMP_DIR/very/deeply/nested/directory/structure" \
  "extremely-long-hostname-for-testing" \
  "feature/TICKET-99999-extremely-long-branch" \
  "organization-production-primary-account" \
  "arn:aws:eks:eu-central-1:999888777666:cluster/production-cluster" \
  "99999999" \
  "99999999" \
  "200000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End
End

# ============================================================================
# SPECIAL CHARACTERS AND EDGE CASES
# ============================================================================

Describe 'Special characters and edge cases'
It 'handles spaces in paths'
When call test_statusline_width "Claude" "$TEMP_DIR/my projects/test app" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles parentheses in model names'
When call test_statusline_width "Claude (Latest)" "$HOME" "host" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles dashes in all components'
When call test_statusline_width \
  "Claude-3-5" \
  "$TEMP_DIR/my-projects/test-app" \
  "dev-host-01" \
  "feature/test-feature-123" \
  "dev-account-01" \
  "dev-cluster-01" \
  "1000" \
  "500" \
  "10000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles underscores in all components'
When call test_statusline_width \
  "Claude_3_5" \
  "$TEMP_DIR/my_projects/test_app" \
  "dev_host_01" \
  "feature/test_feature_123" \
  "dev_account_01" \
  "dev_cluster_01" \
  "1000" \
  "500" \
  "10000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles dots in components'
When call test_statusline_width \
  "Claude.3.5" \
  "$TEMP_DIR/my.projects/test.app" \
  "dev.host.01" \
  "release/v1.2.3" \
  "dev.account" \
  "dev.cluster.com" \
  "1000" \
  "500" \
  "10000"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles mixed special characters'
When call test_statusline_width \
  "Claude-3.5_Sonnet (Oct)" \
  "$TEMP_DIR/my-projects_2024/test.app" \
  "dev_host-01.local" \
  "feature/NEW-123_test.feature" \
  "dev-account.prod_01" \
  "cluster_01-prod.k8s" \
  "1000" \
  "500" \
  "10000"
The output should equal "$EXPECTED_WIDTH"
End
End

# ============================================================================
# EXTREME STRESS TESTS
# ============================================================================

Describe 'Extreme stress tests'
It 'handles maximum everything at once'
When call test_statusline_width \
  "Claude 3.5 Sonnet Latest Extended Version With All Features Enabled And Extra Long Name For Testing Purposes That Should Be Truncated" \
  "$TEMP_DIR/extremely/long/path/that/goes/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on" \
  "extremely-long-hostname-that-exceeds-normal-limits-for-comprehensive-testing-purposes" \
  "feature/TICKET-99999-extremely-long-branch-name-with-many-details-that-should-definitely-be-truncated-somewhere" \
  "organization-production-primary-account-extended-name-with-additional-suffixes-for-testing" \
  "arn:aws:eks:eu-central-1:999888777666:cluster/production-primary-kubernetes-cluster-with-very-long-name-for-testing" \
  "999999999" \
  "999999999" \
  "127999"
The output should equal "$EXPECTED_WIDTH"
End

It 'handles maximum everything in compact mode'
When call test_statusline_width \
  "Claude 3.5 Sonnet Latest Extended Version With All Features Enabled And Extra Long Name For Testing Purposes That Should Be Truncated" \
  "$TEMP_DIR/extremely/long/path/that/goes/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on" \
  "extremely-long-hostname-that-exceeds-normal-limits-for-comprehensive-testing-purposes" \
  "feature/TICKET-99999-extremely-long-branch-name-with-many-details-that-should-definitely-be-truncated-somewhere" \
  "organization-production-primary-account-extended-name-with-additional-suffixes-for-testing" \
  "arn:aws:eks:eu-central-1:999888777666:cluster/production-primary-kubernetes-cluster-with-very-long-name-for-testing" \
  "999999999" \
  "999999999" \
  "200000"
The output should equal "$EXPECTED_WIDTH_COMPACT"
End

It 'handles minimum everything'
When call test_statusline_width "" "" "" "" "" "" "0" "0" "0"
The output should equal "$EXPECTED_WIDTH"
End
End
End

