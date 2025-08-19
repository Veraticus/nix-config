#!/usr/bin/env bash
# smart-lint-simple_spec.sh - Tests for simplified smart-lint.sh

Describe 'smart-lint.sh (simplified)'
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
            When run run_hook_with_json "smart-lint.sh" '{"hook_event_name":"PreToolUse","tool_name":"Edit"}'
            The status should equal 0
            The stderr should equal ""
        End
        
        It 'exits silently for non-edit tools'
            When run run_hook_with_json "smart-lint.sh" '{"hook_event_name":"PostToolUse","tool_name":"Read"}'
            The status should equal 0
            The stderr should equal ""
        End
        
        It 'processes Edit tool'
            # Create a dummy file to edit
            touch test.go
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$TEMP_DIR/test.go")"
            The status should equal 0  # No lint command found
        End
    End
    
    Describe 'Directory traversal'
        It 'walks up to find Makefile with lint target'
            mkdir -p src/nested/deep
            echo -e "lint:\n\t@echo 'Linting...'" > Makefile
            touch src/nested/deep/file.go
            
            cd src/nested/deep || return
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/file.go")"
            The status should equal 2
            The stderr should include "👉 Lints pass"
        End
        
        It 'finds package.json with lint script'
            mkdir -p client/src/components
            echo '{"scripts": {"lint": "echo Linting..."}}' > client/package.json
            touch client/src/components/App.tsx
            
            cd client/src/components || return
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/App.tsx")"
            The status should equal 2
            The stderr should include "👉 Lints pass"
        End
        
        It 'exits silently when no lint command found'
            mkdir -p project/src
            touch project/src/main.py
            
            cd project/src || return
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/main.py")"
            The status should equal 0
            The stderr should equal ""
        End
    End
    
    Describe 'Success and failure handling'
        It 'shows success message when lint passes'
            echo -e "lint:\n\t@exit 0" > Makefile
            touch test.go
            
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/test.go")"
            The status should equal 2
            The stderr should include "👉 Lints pass. Continue with your task."
            The stderr should not include "Linting..."  # Output should be suppressed
        End
        
        It 'shows failure output and blocking message when lint fails'
            echo -e "lint:\n\t@echo 'Error: undefined variable' >&2; exit 1" > Makefile
            touch test.go
            
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/test.go")"
            The status should equal 2
            The stderr should include "⛔ BLOCKING: Run"
            The stderr should include "make lint"
            The stderr should include "to fix lint failures"
        End
    End
    
    Describe 'Package manager detection'
        It 'detects yarn when yarn.lock exists'
            # Create mock yarn command
            mock_command "yarn" 0 "Using yarn"
            
            echo '{"scripts": {"lint": "echo Using yarn"}}' > package.json
            touch yarn.lock
            touch index.js
            
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/index.js")"
            The status should equal 2
            The stderr should include "👉 Lints pass"
        End
        
        It 'detects pnpm when pnpm-lock.yaml exists'
            # Create mock pnpm command
            mock_command "pnpm" 0 "Using pnpm"
            
            echo '{"scripts": {"lint": "echo Using pnpm"}}' > package.json
            touch pnpm-lock.yaml
            touch index.js
            
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/index.js")"
            The status should equal 2
            The stderr should include "👉 Lints pass"
        End
    End
    
    Describe 'Ignore patterns'
        It 'skips files in vendor directories'
            echo -e "lint:\n\t@echo 'Should not run'" > Makefile
            mkdir -p vendor/github.com/pkg
            touch vendor/github.com/pkg/lib.go
            
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/vendor/github.com/pkg/lib.go")"
            The status should equal 0
            The stderr should equal ""
        End
        
        It 'skips files in node_modules'
            echo '{"scripts": {"lint": "echo Should not run"}}' > package.json
            mkdir -p node_modules/lodash
            touch node_modules/lodash/index.js
            
            When run run_hook_with_json "smart-lint.sh" "$(create_post_tool_use_json "Edit" "$PWD/node_modules/lodash/index.js")"
            The status should equal 0
            The stderr should equal ""
        End
    End
End