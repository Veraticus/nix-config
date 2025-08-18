# Claude Code Hooks

Smart, automated code quality checks that run after Claude Code modifies files. The hooks automatically find your project's lint and test commands and run them with intelligent concurrency control.

## 🎯 How It Works

When Claude edits a file, these hooks:
1. **Find your project root** - Walk up the directory tree to find Makefiles, package.json, or other project markers
2. **Run your existing commands** - Execute `make lint`, `npm test`, or other standard commands
3. **Prevent duplicate runs** - Use PID-based locking to ensure only one instance runs per workspace
4. **Show clear feedback** - Display success messages or blocking errors directly in Claude

## 🚀 Quick Start

```bash
# From your project root, ensure you have standard commands:
# - make lint/test
# - npm run lint/test  
# - just lint/test
# - scripts/lint or scripts/test

# That's it! The hooks will automatically find and run them
```

## 📦 Available Hooks

### smart-lint.sh
Automatically runs project lint commands when files are edited:
- Searches for: `make lint`, `npm run lint`, `just lint`, `scripts/lint`, `cargo clippy`, `ruff`/`flake8`/`pylint`
- Walks up directory tree to find project root
- Shows success message or blocks on failures
- Prevents concurrent runs with PID-based locking

### smart-test.sh  
Automatically runs project test commands when files are edited:
- Searches for: `make test`, `npm run test`, `just test`, `scripts/test`, `cargo test`, `pytest`
- Walks up directory tree to find project root
- Shows success message or blocks on failures
- Prevents concurrent runs with PID-based locking

### statusline.sh
Provides a customizable status line for Claude Code showing:
- Current model name
- Working directory
- Git branch and status
- Kubernetes context
- Token usage metrics

### ntfy-notifier.sh
Sends notifications via ntfy.sh when tasks complete or fail.

## 🔧 Configuration

### Environment Variables

```bash
# Enable/disable hooks
export CLAUDE_HOOKS_LINT_ENABLED=true  # Enable/disable smart-lint
export CLAUDE_HOOKS_TEST_ENABLED=true  # Enable/disable smart-test

# Concurrency control
export CLAUDE_HOOKS_LINT_COOLDOWN=2    # Seconds to wait between lint runs (default: 2)
export CLAUDE_HOOKS_TEST_COOLDOWN=2    # Seconds to wait between test runs (default: 2)

# Timeouts
export CLAUDE_HOOKS_LINT_TIMEOUT=10    # Max seconds for lint to run (default: 10)
export CLAUDE_HOOKS_TEST_TIMEOUT=10    # Max seconds for tests to run (default: 10)

# Debug output
export CLAUDE_HOOKS_DEBUG=1            # Show debug messages
```

### Project-Level Configuration

Create `.claude-hooks-config.sh` in your project root:

```bash
# Custom make targets
export CLAUDE_HOOKS_MAKE_LINT_TARGETS="lint check"
export CLAUDE_HOOKS_MAKE_TEST_TARGETS="test test-unit"

# Custom script names
export CLAUDE_HOOKS_SCRIPT_LINT_NAMES="lint.sh check.sh"
export CLAUDE_HOOKS_SCRIPT_TEST_NAMES="test.sh run-tests.sh"

# Disable project command discovery entirely
export CLAUDE_HOOKS_USE_PROJECT_COMMANDS=false
```

### Ignore Patterns

Create `.claude-hooks-ignore` in your project root:

```
# Ignore specific files
generated.go
*.pb.go

# Ignore directories
vendor/**
node_modules/**
build/**

# Ignore by pattern
*.test.js
*_test.go
```

## 🛠️ How the Locking Works

The hooks use a sophisticated PID-based locking mechanism:

1. **Lock file location**: `/tmp/claude-hook-{lint|test}-<workspace-hash>.lock`
2. **Lock file format**:
   - Line 1: PID of running process (empty if not running)
   - Line 2: Timestamp of last completion
3. **Behavior**:
   - If another instance is running (PID exists and is alive) → Exit immediately
   - If completed within cooldown period → Exit immediately  
   - Otherwise → Run and update lock file

This ensures:
- No duplicate runs in the same workspace
- No rapid successive runs (configurable cooldown)
- Graceful handling of crashed processes

## 🔍 Hook Protocol

Claude Code hooks follow a JSON-based protocol:

### Input
Hooks receive JSON via stdin when triggered:
```json
{
  "hook_event_name": "PostToolUse",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/path/to/file.go"
  }
}
```

### Exit Codes
- `0` - Success, continue silently
- `2` - Show message to user (for both success and failure messages)

## 📚 Additional Documentation

- **[QUICK_START.md](QUICK_START.md)** - Get started in 5 minutes
- **[INTEGRATION.md](INTEGRATION.md)** - Detailed integration guide
- **[example-Makefile](example-Makefile)** - Copy-paste Makefile template
- **[example-claude-hooks-config.sh](example-claude-hooks-config.sh)** - Configuration options

## 💡 Tips

1. **Standard commands work best** - Use `make lint`, `npm run test`, etc.
2. **Hooks walk up** - They'll find commands in parent directories
3. **Fast feedback** - Keep lint/test commands fast (< 10 seconds)
4. **Clear output** - Hooks suppress output on success, show it on failure
5. **Project-specific config** - Use `.claude-hooks-config.sh` for custom settings

## 🧪 Testing

Run the test suite:
```bash
cd ~/.claude/hooks
make test  # Run all tests
make lint  # Run shellcheck
make check # Run both
```

## 🤝 Contributing

The hooks are managed via Nix configuration in this repository. To modify:
1. Edit files in `home-manager/claude-code/hooks/`
2. Run `make check` to validate
3. Run `update` to apply changes system-wide