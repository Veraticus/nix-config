# Claude Code Hook Development Guidelines

This document provides specific guidance for Claude when working with the Claude Code hooks in this directory.

## CRITICAL: Exit Code Behavior

Claude Code hooks use specific exit codes:

- **Exit 0**: Continue operation silently (no user feedback)
- **Exit 1**: General error (missing dependencies, configuration issues)
- **Exit 2**: Display message to user (for BOTH errors AND success!)

**IMPORTANT**: Exit code 2 is used for ANY message that should be shown to the user:
- Error messages: `exit 2` with red error text
- Success messages: `exit 2` with green success text (e.g., "✅ All style checks passed")
- This allows hooks to provide positive feedback, not just error reporting

### Example Patterns

```bash
# Success with feedback (common pattern)
echo -e "${GREEN}✅ All tests passed${NC}" >&2
exit 2  # Show success message to user

# Error with feedback
echo -e "${RED}❌ Linting failed${NC}" >&2
exit 2  # Block operation and show error

# Silent success (less common)
exit 0  # Continue without feedback
```

When writing tests, remember:
- `The status should equal 2` for BOTH success and error cases that show messages
- Check stderr content to verify success vs error
- `The status should equal 0` only for truly silent operations

## CRITICAL: ShellSpec Test Syntax

### ⚠️ NEVER USE INLINE BEFOREEACH/AFTEREACH BLOCKS ⚠️

ShellSpec does **NOT** support inline code blocks for `BeforeEach`/`AfterEach`. This invalid syntax will cause "Unexpected 'End'" errors:

```bash
# ❌ INVALID - THIS DOES NOT WORK
BeforeEach
    TEMP_DIR=$(create_test_dir)
    cd "$TEMP_DIR" || return
End

# ❌ ALSO INVALID - MIXING FUNCTION NAME WITH INLINE CODE
BeforeEach 'setup_test'
    TEMP_DIR=$(create_test_dir)
    cd "$TEMP_DIR" || return
End
```

### ✅ CORRECT: Use Function Definitions

ShellSpec **ONLY** supports function references for hooks:

```bash
# ✅ CORRECT - Define function first, then reference it
setup_test() {
    TEMP_DIR=$(create_test_dir)
    cd "$TEMP_DIR" || return
    export CLAUDE_HOOKS_DEBUG=0
}

cleanup_test() {
    cd "$SPEC_DIR" || return
    rm -rf "$TEMP_DIR"
}

BeforeEach 'setup_test'
AfterEach 'cleanup_test'
```

### Other Critical ShellSpec Rules

1. **No `Include spec_helper`** - ShellSpec automatically loads spec_helper.sh via `--require spec_helper` in .shellspec
2. **One evaluation per test** - Only one `When call` statement allowed per `It` block
3. **Array testing** - Cannot use `The length of ARRAY_NAME`. Test array elements individually.
4. **Pattern matching** - Use `[[]` to match literal `[` in patterns

### Common Pitfalls to Avoid

- **DO NOT** try to create inline BeforeEach/AfterEach blocks - they are not supported
- **DO NOT** put `Include spec_helper` inside Describe blocks
- **DO NOT** use multiple `When call` statements in a single test
- **DO NOT** ignore the `--fail-fast` issue - it can mask real test failures with cryptic errors

### Debugging Test Failures

When tests fail unexpectedly:

1. **Use ShellSpec's `Dump` helper** to see actual output:
   ```bash
   When run some_command
   Dump  # Shows stdout, stderr, and status
   The status should equal 0
   ```

2. **Use the debug formatter** for detailed output:
   ```bash
   shellspec spec/test_spec.sh -f debug
   ```

3. **Add debug logging to hooks**:
   ```bash
   log_debug "Current state: $VAR"
   ```
   Then use the `run_hook_with_json_debug` helper in tests.

**Note**: If a test suddenly passes after adding `Dump`, this may indicate timing issues or ShellSpec state problems.

## Hook Implementation Guidelines

### JSON Protocol

All hooks must properly implement the Claude Code JSON protocol:

1. Read JSON from stdin
2. Parse event type, tool name, and parameters
3. Process only PostToolUse events for relevant tools
4. Use proper exit codes:
   - 0: Continue operation
   - 1: Error (missing dependencies, etc.)
   - 2: Block operation (linting/test failures)

### Directory Structure

```
hooks/
├── common-helpers.sh      # Shared utilities
├── smart-lint.sh         # Main linting orchestrator
├── smart-test.sh         # Main testing orchestrator
├── lint-*.sh            # Language-specific linters
├── test-*.sh            # Language-specific test runners
├── spec/                # ShellSpec tests
│   ├── spec_helper.sh   # Test utilities (auto-loaded)
│   └── *_spec.sh        # Test files
└── tests/               # Legacy test files
```

### Testing Commands

```bash
# Run all tests
make test

# Run only ShellSpec tests
make shellspec

# Run shellcheck on all scripts
make lint

# Run everything
make check
```