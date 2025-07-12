#!/usr/bin/env bash
# smart-test_spec.sh - Tests for smart testing orchestrator

# Note: spec_helper.sh is automatically loaded by ShellSpec via --require spec_helper

# Custom matcher for status that accepts 0 or 2
status_is_0_or_2() {
    [ "${status_is_0_or_2:?}" -eq 0 ] || [ "${status_is_0_or_2:?}" -eq 2 ]
}

# Setup and cleanup functions
setup_go_pass() {
    setup_test_with_fixture "smart-test" "go-tests-pass"
}

setup_go_fail() {
    setup_test_with_fixture "smart-test" "go-tests-fail"
}

setup_python_pass() {
    setup_test_with_fixture "smart-test" "python-tests-pass"
}

setup_ignore_patterns() {
    setup_test_with_fixture "smart-test" "ignore-patterns"
}

cleanup() {
    cleanup_test
}

Describe 'smart-test.sh'
    Describe 'JSON input handling'
        BeforeEach 'setup_go_pass'
        AfterEach 'cleanup'
        
        It 'processes PostToolUse Edit events'
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "math.go")"
            The status should equal 2
            The stderr should include "Tests pass. Continue with your task."
        End
        
        It 'processes PostToolUse Write events'
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Write" "math.go")"
            The status should equal 2
            The stderr should include "Tests pass. Continue with your task."
        End
        
        It 'processes PostToolUse MultiEdit events'
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "MultiEdit" "math.go")"
            The status should equal 2
            The stderr should include "Tests pass. Continue with your task."
        End
        
        It 'ignores non-PostToolUse events'
            When run run_hook_with_json "smart-test.sh" '{"event":"PreToolUse","tool":"Edit"}'
            The status should equal 0
            The output should equal ""
        End
        
        It 'ignores non-edit tools'
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Read" "math.go")"
            The status should equal 0
            The output should equal ""
        End
    End
    
    Describe 'Go project testing'
        Describe 'passing tests'
            BeforeEach 'setup_go_pass'
            AfterEach 'cleanup'
            
            It 'runs tests and returns 2 when tests pass'
                When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "math.go")"
                The status should equal 2
                The stderr should include "Tests pass. Continue with your task."
            End
        End
        
        Describe 'failing tests'
            BeforeEach 'setup_go_fail'
            AfterEach 'cleanup'
            
            It 'runs tests and returns 2 when tests fail'
                When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "broken.go")"
                The status should equal 2
                The stderr should include "FAIL"
            End
        End
    End
    
    Describe 'Python project testing'
        BeforeEach 'setup_python_pass'
        AfterEach 'cleanup'
        
        It 'detects and runs Python tests'
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "calculator.py")"
            The status should satisfy status_is_0_or_2
            # Python tests pass, so expect success message if status is 2
            The stderr should be present
        End
    End
    
    Describe 'Ignore patterns'
        BeforeEach 'setup_ignore_patterns'
        AfterEach 'cleanup'
        
        It 'respects .claude-hooks-ignore patterns'
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "ignored.go")"
            The status should equal 0
            The output should equal ""
        End
    End
    
    
    Describe 'Project detection'
        It 'handles projects without test files gracefully'
            cd "$SHELLSPEC_TMPBASE"
            mkdir -p no-tests
            cd no-tests
            echo "module testproject" > go.mod
            create_go_file "main.go"
            
            When run run_hook_with_json "smart-test.sh" "$(create_post_tool_use_json "Edit" "main.go")"
            The status should equal 2
            The stderr should include "Tests pass. Continue with your task."
        End
    End
    
    Describe 'Debug mode'
        BeforeEach 'setup_go_pass'
        AfterEach 'cleanup'
        
        It 'shows debug output when enabled'
            When run run_hook_with_json_debug "smart-test.sh" "$(create_post_tool_use_json "Edit" "math.go")"
            The status should equal 2
            The output should include "DEBUG:"
            The output should include "Detected Go file/project"
            The output should include "Tests pass. Continue with your task."
        End
    End
End