#!/usr/bin/env bash
# Test suite for smart-lint.sh deduplication functionality

# Include the spec helper
# shellcheck source=../spec_helper.sh

Describe 'smart-lint.sh deduplication'
    setup_test() {
        # Create a test directory and set it as a git repo
        export TEMP_DIR
        TEMP_DIR=$(create_test_dir)
        cd "$TEMP_DIR" || return
        
        # Initialize as a git repo for consistent project ID
        git init --quiet 2>/dev/null || true
        
        # Create a simple Go file
        create_go_file "test.go"
        
        # Mock commands
        mock_command "golangci-lint" 0
        mock_command "gofmt" 0
        mock_command "deadcode" 0
        
        # Enable debug mode for testing
        export CLAUDE_HOOKS_DEBUG=1
        
        # Clear any existing locks
        rm -rf /tmp/claude-hooks-lint-locks 2>/dev/null || true
    }
    
    cleanup_test() {
        cd "$SPEC_DIR" || return
        rm -rf "$TEMP_DIR"
        # Clean up locks
        rm -rf /tmp/claude-hooks-lint-locks 2>/dev/null || true
    }
    
    BeforeEach 'setup_test'
    AfterEach 'cleanup_test'
    
    Describe 'lock acquisition'
        It 'acquires lock on first run'
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Acquired lock for project"
            The stderr should include "Hook completed successfully"
        End
        
        It 'skips when another instance is running'
            # Create a lock file manually to simulate another process
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            
            # Create a valid lock from the current shell (which is alive)
            echo "$$:$(date +%s)" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 0
            The stderr should include "Another lint process is already running"
            
            # Clean up lock file
            rm -f "$lock_file"
        End
        
        It 'removes stale lock from dead process'
            # Create a fake lock with a non-existent PID
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            echo "999999:$(date +%s)" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Removing lock from dead process"
            The stderr should include "Acquired lock for project"
            The stderr should include "Hook completed successfully"
        End
        
        It 'removes lock with invalid content'
            # Create a lock with invalid content
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            echo "invalid content" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Removing lock with invalid/old format"
            The stderr should include "Acquired lock for project"
            The stderr should include "Hook completed successfully"
        End
        
        It 'removes old timestamp lock'
            # Create a lock with old timestamp (40 seconds ago)
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            old_timestamp=$(($(date +%s) - 40))
            echo "$$:$old_timestamp" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Removing stale lock"
            The stderr should include "Acquired lock for project"
            The stderr should include "Hook completed successfully"
        End
        
        It 'respects valid lock from current process'
            # This test verifies that we don't remove our own valid lock
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            
            # First run to create lock
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Hook completed successfully"
            
            # Verify completion marker exists and has correct format
            The file "$lock_file" should be exist
            lock_content=$(cat "$lock_file")
            # Should have completion marker format: 0:START:COMPLETION
            The value "$lock_content" should match pattern "0:*:*"
        End
    End
    
    Describe 'lock cleanup'
        It 'cleans up lock on normal exit'
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Released lock for project:"
            The file "$lock_file" should be exist
            # Should contain completion marker (0:START:COMPLETION)
            lock_content=$(cat "$lock_file")
            The value "$lock_content" should match pattern "0:*:*"
        End
        
        It 'only releases its own lock'
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            
            # Create a lock owned by different process
            echo "99999:$(date +%s)" > "$lock_file"
            
            # The lock should still exist after attempting to release it
            # (since release_lock only removes locks owned by current process)
            
            # Source just the lock functions to test release_lock
            (
                export LOCK_DIR="/tmp/claude-hooks-lint-locks"
                # Source logging functions
                log_debug() { :; }
                
                # Define release_lock from smart-lint.sh
                release_lock() {
                    local project_id="$1"
                    local lock_file="$LOCK_DIR/lint-${project_id}.lock"
                    
                    if [[ -f "$lock_file" ]]; then
                        local lock_content
                        lock_content=$(cat "$lock_file" 2>/dev/null || echo "")
                        
                        if [[ "$lock_content" =~ ^$$: ]]; then
                            rm -f "$lock_file" 2>/dev/null || true
                        fi
                    fi
                }
                
                release_lock "$project_id"
            )
            
            # Lock should still exist since it's not ours
            The file "$lock_file" should be exist
        End
    End
    
    Describe 'MultiEdit deduplication'
        It 'handles multiple files from same project'
            # Create multiple files
            create_go_file "file1.go"
            create_go_file "file2.go"
            create_go_file "file3.go"
            
            # Create a lock file manually to simulate another process
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            echo "$$:$(date +%s)" > "$lock_file"
            
            # Run hook with lock present
            json=$(create_post_tool_use_json "MultiEdit" "file1.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 0
            The stderr should include "Another lint process is already running"
            
            # Clean up
            rm -f "$lock_file"
        End
    End
    
    Describe 'project identification'
        It 'uses git root for project ID when in git repo'
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            # The project ID should be based on git root
            The stderr should include "Acquired lock for project:"
            The stderr should include "Hook completed successfully"
        End
        
        It 'uses current directory when not in git repo'
            # Remove git repo
            rm -rf .git
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            # Should still work but use pwd-based project ID
            The stderr should include "Acquired lock for project:"
            The stderr should include "Hook completed successfully"
        End
    End
    
    Describe 'Cooldown period'
        It 'skips lint when completed recently (within cooldown)'
            # Set a short cooldown for testing
            export CLAUDE_HOOKS_LINT_COOLDOWN=5
            
            # Create a completion marker (format: 0:START:COMPLETION)
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            
            # Simulate a lint that completed 2 seconds ago
            current_time=$(date +%s)
            start_time=$((current_time - 10))
            completion_time=$((current_time - 2))
            echo "0:${start_time}:${completion_time}" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 0
            The stderr should include "Skipping lint - completed"
            The stderr should include "cooldown: 5s"
        End
        
        It 'runs lint when cooldown has expired'
            # Set a short cooldown for testing
            export CLAUDE_HOOKS_LINT_COOLDOWN=3
            
            # Create a completion marker for a lint that completed 5 seconds ago
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            
            current_time=$(date +%s)
            start_time=$((current_time - 15))
            completion_time=$((current_time - 5))
            echo "0:${start_time}:${completion_time}" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Cooldown expired"
            The stderr should include "Hook completed successfully"
        End
        
        It 'creates completion marker after successful lint'
            json=$(create_post_tool_use_json "Edit" "test.go")
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            
            # Run the hook
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Hook completed successfully"
            
            # Check that completion marker was created
            The file "$lock_file" should be exist
            lock_content=$(cat "$lock_file")
            # Should have format: 0:START:COMPLETION
            The value "$lock_content" should match pattern "0:*:*"
        End
        
        It 'respects custom cooldown period'
            # Set a custom cooldown period
            export CLAUDE_HOOKS_LINT_COOLDOWN=15
            
            # Create a completion marker for a lint that completed 8 seconds ago
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            
            current_time=$(date +%s)
            start_time=$((current_time - 20))
            completion_time=$((current_time - 8))
            echo "0:${start_time}:${completion_time}" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 0
            The stderr should include "cooldown: 15s"
        End
        
        It 'removes old format locks and acquires new lock'
            # Create an old format lock (any format that's not PID:START or 0:START:COMPLETION)
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            
            # Use old format (single timestamp)
            echo "$(date +%s)" > "$lock_file"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Removing lock with invalid/old format"
            The stderr should include "Hook completed successfully"
        End
    End
End