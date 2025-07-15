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
            The stderr should include "Removing lock with invalid content"
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
            run_hook_with_json "smart-lint.sh" "$json" >/dev/null 2>&1
            
            # Verify lock exists and has correct format
            The file "$lock_file" should be exist
            lock_content=$(cat "$lock_file")
            The output "$lock_content" should match pattern "*:*"
        End
    End
    
    Describe 'lock cleanup'
        It 'cleans up lock on normal exit'
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            
            json=$(create_post_tool_use_json "Edit" "test.go")
            When run run_hook_with_json "smart-lint.sh" "$json"
            The status should equal 2
            The stderr should include "Released lock for project"
            The file "$lock_file" should not be exist
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
            
            # Run first hook to acquire lock
            json1=$(create_post_tool_use_json "MultiEdit" "file1.go")
            output1=$(echo "$json1" | "$HOOKS_DIR/smart-lint.sh" 2>&1)
            
            # Verify first one acquired the lock
            echo "$output1" | grep -q "Acquired lock for project" || {
                echo "First run did not acquire lock as expected" >&2
                echo "Output: $output1" >&2
                return 1
            }
            
            # Now immediately run second one while lock is still held
            # We need to manually create the lock since the first run already completed
            project_id=$(pwd | tr '/' '_')
            lock_file="/tmp/claude-hooks-lint-locks/lint-${project_id}.lock"
            mkdir -p "$(dirname "$lock_file")"
            echo "1:$(date +%s)" > "$lock_file"
            
            json2=$(create_post_tool_use_json "MultiEdit" "file2.go")
            output2=$(echo "$json2" | "$HOOKS_DIR/smart-lint.sh" 2>&1)
            
            # Second one should skip
            echo "$output2" | grep -q "Another lint process is already running" || {
                echo "Second run did not skip as expected" >&2
                echo "Output: $output2" >&2
                return 1
            }
            
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
End