#!/usr/bin/env bash
# statusline_spec.sh - Tests for the Claude Code status line

Describe 'statusline.sh'
    # Note: spec_helper.sh is automatically loaded by ShellSpec via --require spec_helper
    
    # Test setup functions
    setup_test() {
        export CLAUDE_HOOKS_DEBUG=0
        # Create temp directory for test
        TEMP_DIR=$(create_test_dir)
        cd "$TEMP_DIR" || return
        # Store actual hostname for tests
        ACTUAL_HOSTNAME=$(hostname -s)
    }
    
    cleanup_test() {
        cd "$SPEC_DIR" || return
        rm -rf "$TEMP_DIR"
    }
    
    BeforeEach 'setup_test'
    AfterEach 'cleanup_test'
    
    Describe 'basic functionality'
        It 'produces output with minimal JSON input'
            When call sh -c "echo '{}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include '~'
            The stdout should match pattern '*[0m*'
        End
        
        It 'displays model name when provided'
            When call sh -c "echo '{\"model\":{\"display_name\":\"Opus\"}}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include 'Opus'
        End
        
        It 'falls back to Claude when model not provided'
            When call sh -c "echo '{}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include 'Claude'
        End
        
        It 'displays current directory'
            When call sh -c "echo '{\"workspace\":{\"current_dir\":\"/home/user/project\"}}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include 'project'
        End
    End
    
    Describe 'path formatting'
        It 'replaces home directory with ~'
            When call sh -c "echo '{\"workspace\":{\"current_dir\":\"'\"$HOME\"'/myproject\"}}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include '~/myproject'
        End
        
        It 'truncates long paths'
            When call sh -c "echo '{\"workspace\":{\"current_dir\":\"'\"$HOME\"'/very/long/path/to/project\"}}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include '~/to/project'
        End
        
        It 'handles root paths'
            When call sh -c "echo '{\"workspace\":{\"current_dir\":\"/usr/local/bin\"}}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include 'local/bin'
        End
    End
    
    Describe 'hostname display'
        It 'shows hostname'
            When call sh -c "echo '{}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include "$ACTUAL_HOSTNAME"
        End
    End
    
    Describe 'ANSI colors'
        It 'includes ANSI escape codes for colors'
            When call sh -c "echo '{}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            # Check for ANSI escape sequences
            The stdout should match pattern '*[0m*'
        End
        
        It 'includes chevron characters'
            When call sh -c "echo '{}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include ''
        End
    End
    
    Describe 'complete status line'
        It 'generates full status line with all components'
            When call sh -c "echo '{\"model\":{\"display_name\":\"Opus\"},\"workspace\":{\"current_dir\":\"'\"$HOME\"'/project\"}}' | bash '$HOOK_DIR/statusline.sh'"
            The status should equal 0
            The stdout should include '~/project'
            The stdout should include 'Opus'
            The stdout should include "$ACTUAL_HOSTNAME"
            The stdout should include ''
        End
    End
End