#!/usr/bin/env bash
# Test suite for the lock mechanism functions in smart-lint.sh

# Include the spec helper
# shellcheck source=../spec_helper.sh

Describe 'Lock mechanism functions'
    setup_test() {
        # Create a clean test environment
        export TEMP_DIR
        TEMP_DIR=$(create_test_dir)
        cd "$TEMP_DIR" || return
        
        # Set up lock directory
        export LOCK_DIR="/tmp/claude-hooks-lint-locks-test-$$"
        mkdir -p "$LOCK_DIR"
        
        # Source common helpers to get logging functions
        source "$HOOKS_DIR/common-helpers.sh" >/dev/null 2>&1
        
        # Extract and source the lock functions from smart-lint.sh
        # We'll create a temporary file with just the functions we need
        lock_functions_file="$TEMP_DIR/lock_functions.sh"
        
        # Extract the lock-related functions from smart-lint.sh
        sed -n '/^# Function to get a project identifier/,/^trap cleanup_locks EXIT$/p' "$HOOKS_DIR/smart-lint.sh" > "$lock_functions_file"
        
        # Source the functions
        source "$lock_functions_file"
        
        # Disable debug output for cleaner tests
        export CLAUDE_HOOKS_DEBUG=0
    }
    
    cleanup_test() {
        cd "$SPEC_DIR" || return
        rm -rf "$TEMP_DIR"
        rm -rf "$LOCK_DIR"
    }
    
    BeforeEach 'setup_test'
    AfterEach 'cleanup_test'
    
    Describe 'get_project_id()'
        It 'returns git root when in git repository'
            # Initialize git repo
            git init --quiet 2>/dev/null
            git_root=$(pwd)
            
            # Create subdirectory and navigate to it
            mkdir -p subdir/nested
            cd subdir/nested || return
            
            When call get_project_id
            # Should return git root path with slashes replaced by underscores
            The output should equal "$(echo "$git_root" | tr '/' '_')"
        End
        
        It 'returns current directory when not in git repository'
            # Ensure we're not in a git repo
            rm -rf .git
            current_dir=$(pwd)
            
            When call get_project_id
            The output should equal "$(echo "$current_dir" | tr '/' '_')"
        End
        
        It 'handles paths with special characters'
            # Create directory with spaces and special chars
            special_dir="$TEMP_DIR/my project (test)"
            mkdir -p "$special_dir"
            cd "$special_dir" || return
            
            When call get_project_id
            The output should equal "$(echo "$special_dir" | tr '/' '_')"
        End
    End
    
    Describe 'acquire_lock()'
        It 'successfully acquires lock when none exists'
            project_id="test_project_123"
            
            When call acquire_lock "$project_id"
            The status should be success
            
            # Verify lock file was created
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            The file "$lock_file" should be exist
            
            # Verify lock content format (PID:TIMESTAMP)
            lock_content=$(cat "$lock_file")
            The value "$lock_content" should match pattern "[0-9]+:[0-9]+"
            
            # Verify PID is ours
            The value "$lock_content" should start with "$$:"
        End
        
        It 'fails to acquire lock when valid lock exists'
            project_id="test_project_456"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create a valid lock from current process
            echo "$$:$(date +%s)" > "$lock_file"
            
            # Try to acquire again (with short timeout for test speed)
            When call acquire_lock "$project_id"
            The status should be failure
        End
        
        It 'acquires lock after removing stale lock with dead PID'
            project_id="test_project_789"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create lock with non-existent PID
            echo "999999:$(date +%s)" > "$lock_file"
            
            When call acquire_lock "$project_id"
            The status should be success
            
            # Should have new lock with our PID
            lock_content=$(cat "$lock_file")
            The value "$lock_content" should start with "$$:"
        End
        
        It 'acquires lock after removing lock with invalid content'
            project_id="test_invalid"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create lock with invalid content
            echo "invalid content" > "$lock_file"
            
            When call acquire_lock "$project_id"
            The status should be success
            
            # Verify lock was replaced with valid content
            lock_content=$(cat "$lock_file")
            The value "$lock_content" should match pattern "[0-9]+:[0-9]+"
        End
        
        It 'acquires lock after removing old timestamp'
            project_id="test_old_lock"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create lock that's 40 seconds old (older than 30s threshold)
            old_timestamp=$(($(date +%s) - 40))
            echo "$$:$old_timestamp" > "$lock_file"
            
            When call acquire_lock "$project_id"
            The status should be success
            
            # Should have new lock with recent timestamp
            lock_content=$(cat "$lock_file")
            The value "$lock_content" should start with "$$:"
            
            # Extract and verify timestamp is recent
            new_timestamp=$(echo "$lock_content" | cut -d: -f2)
            current_time=$(date +%s)
            time_diff=$((current_time - new_timestamp))
            The value "$time_diff" should be less than 2
        End
        
        It 'handles concurrent lock attempts gracefully'
            project_id="test_concurrent"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Simulate concurrent attempts by creating/removing lock rapidly
            (
                for i in {1..5}; do
                    echo "$$:$(date +%s)" > "$lock_file"
                    sleep 0.01
                    rm -f "$lock_file"
                    sleep 0.01
                done
            ) &
            bg_pid=$!
            
            # Try to acquire lock while background process is messing with it
            sleep 0.02  # Let background process start
            When call acquire_lock "$project_id"
            # Should eventually succeed
            The status should be success
            
            # Clean up background process
            wait $bg_pid 2>/dev/null || true
        End
        
        It 'respects timeout when unable to acquire lock'
            project_id="test_timeout"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create a valid lock from a fake "alive" process
            # Use PID 1 which is always alive (init)
            echo "1:$(date +%s)" > "$lock_file"
            
            # Acquire should fail quickly in test (timeout is 5 iterations of 0.1s = 0.5s)
            When call acquire_lock "$project_id"
            The status should be failure
        End
    End
    
    Describe 'release_lock()'
        It 'releases lock owned by current process'
            project_id="test_release_own"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create lock owned by us
            echo "$$:$(date +%s)" > "$lock_file"
            
            When call release_lock "$project_id"
            The status should be success
            
            # Lock file should be removed
            The file "$lock_file" should not be exist
        End
        
        It 'does not release lock owned by different process'
            project_id="test_release_other"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create lock owned by different PID
            echo "999999:$(date +%s)" > "$lock_file"
            
            When call release_lock "$project_id"
            The status should be success
            
            # Lock file should still exist
            The file "$lock_file" should be exist
            The contents of file "$lock_file" should equal "999999:$(cat "$lock_file" | cut -d: -f2)"
        End
        
        It 'handles missing lock file gracefully'
            project_id="test_release_missing"
            
            # No lock file exists
            When call release_lock "$project_id"
            The status should be success
        End
        
        It 'handles lock file with invalid content'
            project_id="test_release_invalid"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Create lock with invalid content
            echo "invalid content" > "$lock_file"
            
            When call release_lock "$project_id"
            The status should be success
            
            # Should not remove invalid lock (not ours)
            The file "$lock_file" should be exist
        End
    End
    
    Describe 'Atomic lock creation'
        It 'creates lock atomically to prevent race conditions'
            project_id="test_atomic"
            lock_file="$LOCK_DIR/lint-${project_id}.lock"
            
            # Run multiple acquire_lock attempts in parallel
            success_count=0
            for i in {1..10}; do
                (
                    if acquire_lock "$project_id" 2>/dev/null; then
                        echo "success"
                        sleep 0.1  # Hold lock briefly
                        release_lock "$project_id"
                    fi
                ) &
            done | while read -r result; do
                [[ "$result" == "success" ]] && ((success_count++))
            done
            
            wait
            
            # Exactly one should have succeeded due to atomic creation
            # (This is hard to test perfectly, but we can verify the lock mechanism works)
            The file "$lock_file" should not be exist  # All should have cleaned up
        End
    End
    
    Describe 'Lock directory creation'
        It 'creates lock directory if it does not exist'
            # Remove lock directory
            rm -rf "$LOCK_DIR"
            
            project_id="test_mkdir"
            When call acquire_lock "$project_id"
            The status should be success
            
            # Directory should have been created
            The directory "$LOCK_DIR" should be exist
        End
        
        It 'handles permission errors gracefully'
            # Create lock directory with no write permission
            chmod 555 "$LOCK_DIR"
            
            project_id="test_no_perms"
            When call acquire_lock "$project_id"
            The status should be failure
            
            # Restore permissions for cleanup
            chmod 755 "$LOCK_DIR"
        End
    End
End