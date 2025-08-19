#!/usr/bin/env bash
# smart-test-simple_spec.sh - Tests for simplified smart-test.sh

Describe 'smart-test.sh (simplified)'
    # Test setup functions
    setup_test() {
        export CLAUDE_HOOKS_DEBUG=0
        TEMP_DIR=$(create_test_dir)
        cd "$TEMP_DIR" || return
    }
    
    cleanup_test() {
        cd "$SPEC_DIR" || return
        rm -rf "$TEMP_DIR"
    }
    
    BeforeEach 'setup_test'
    AfterEach 'cleanup_test'
    
    Describe 'JSON input processing'
        It 'exits silently when not PostToolUse'
            When run run_hook_with_json "smart-test.sh" '{"hook_event_name":"PreToolUse","tool_name":"Edit"}'
            The status should equal 0
            The stderr should equal ""
        End
        
        It 'exits silently for non-edit tools'
            When run run_hook_with_json "smart-test.sh" '{"hook_event_name":"PostToolUse","tool_name":"Bash"}'
            The status should equal 0
            The stderr should equal ""
        End
        
        It 'processes Write tool'
            touch newfile.go
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Write" "$TEMP_DIR/newfile.go")"
            The status should equal 0  # No test command found
        End
    End
    
    Describe 'Directory traversal'
        It 'walks up to find Makefile with test target'
            mkdir -p src/handlers
            echo -e "test:\n\t@echo 'Running tests...'" > Makefile
            touch src/handlers/api.go
            
            cd src/handlers || return
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/api.go")"
            The status should equal 2
            The stderr should include "👉 Tests pass"
        End
        
        It 'finds package.json with test script'
            mkdir -p app/src/utils
            echo '{"scripts": {"test": "echo Testing..."}}' > app/package.json
            touch app/src/utils/helper.js
            
            cd app/src/utils || return
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/helper.js")"
            The status should equal 2
            The stderr should include "👉 Tests pass"
        End
        
        It 'finds scripts/test executable'
            mkdir -p lib/internal
            mkdir scripts
            echo -e "#!/usr/bin/env bash\necho 'Running tests...'" > scripts/test
            chmod +x scripts/test
            touch lib/internal/core.py
            
            cd lib/internal || return
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/core.py")"
            The status should equal 2
            The stderr should include "👉 Tests pass"
        End
        
        It 'exits silently when no test command found'
            mkdir -p project/src
            touch project/src/main.rs
            
            cd project/src || return
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/main.rs")"
            The status should equal 0
            The stderr should equal ""
        End
    End
    
    Describe 'Success and failure handling'
        It 'shows success message and suppresses output when tests pass'
            echo -e "test:\n\t@echo 'Test output that should be hidden'; exit 0" > Makefile
            touch test.go
            
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/test.go")"
            The status should equal 2
            The stderr should include "👉 Tests pass. Continue with your task."
            The stderr should not include "Test output that should be hidden"
        End
        
        It 'shows test failures and blocking message when tests fail'
            echo -e "test:\n\t@echo 'FAIL: TestAdd (0.01s)' >&2; echo '    expected 4, got 5' >&2; exit 1" > Makefile
            touch calculator.go
            
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/calculator.go")"
            The status should equal 2
            The stderr should include "⛔ BLOCKING: Run"
            The stderr should include "make test"
            The stderr should include "to fix test failures"
            The stdout should not include "FAIL: TestAdd"  # We don't show output anymore
        End
        
        It 're-runs test command to show output on failure'
            # Create a test that outputs different things each time (to verify re-run)
            echo -e "test:\n\t@echo 'Test failed with details' >&2; exit 1" > Makefile
            touch code.py
            
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/code.py")"
            The status should equal 2
            The stderr should include "⛔ BLOCKING: Run"
            The stderr should include "make test"
            The stdout should not include "Test failed with details"  # We don't show output anymore
        End
    End
    
    Describe 'Build system detection'
        It 'prefers Makefile over package.json in same directory'
            echo -e "test:\n\t@echo 'Make test'" > Makefile
            echo '{"scripts": {"test": "echo npm test"}}' > package.json
            touch file.go
            
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/file.go")"
            The status should equal 2
            The stderr should include "👉 Tests pass"
        End
        
        It 'detects justfile'
            cat > justfile << 'EOF'
test:
    @echo "Just test"
EOF
            touch main.rs
            
            # Skip if just is not installed
            if command -v just &>/dev/null; then
                When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/main.rs")"
                The status should equal 2
                The stderr should include "👉 Tests pass"
            else
                Skip "just command not available"
            fi
        End
    End
    
    Describe 'Ignore patterns'
        It 'skips test files themselves'
            echo -e "test:\n\t@echo 'Should not run for test files'" > Makefile
            touch calculator_test.go
            
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/calculator_test.go")"
            The status should equal 0
            The stderr should equal ""
        End
        
        It 'skips files in build directories'
            echo -e "test:\n\t@echo 'Should not run'" > Makefile
            mkdir -p build/gen
            touch build/gen/proto.go
            
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "$PWD/build/gen/proto.go")"
            The status should equal 0
            The stderr should equal ""
        End
    End
End