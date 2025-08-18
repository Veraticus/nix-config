# Integration Guide

This guide explains how to integrate Claude Code hooks with your projects for automatic code quality checks.

## Overview

The Claude Code hooks work with your **existing** project commands. There's no complex setup required - if you already have `make lint` or `npm test`, the hooks will find and use them automatically.

## How It Works

### 1. Automatic Discovery
When Claude edits a file, the hooks:
- Start from the edited file's directory
- Walk up the directory tree looking for project markers
- Stop when they find a command to run or reach the project root

### 2. Project Markers
The hooks recognize these as project roots:
- `.git/` directory
- `go.mod` (Go projects)
- `package.json` (Node.js projects)
- `Cargo.toml` (Rust projects)
- `setup.py` or `pyproject.toml` (Python projects)

### 3. Command Search Order
For **linting**, the hooks look for (in order):
1. `make lint` (Makefile)
2. `just lint` (Justfile)
3. `npm/yarn/pnpm run lint` (package.json)
4. `./scripts/lint` (executable script)
5. `cargo clippy` (Rust projects)
6. `ruff`, `flake8`, or `pylint` (Python projects)

For **testing**, the hooks look for:
1. `make test` (Makefile)
2. `just test` (Justfile)
3. `npm/yarn/pnpm run test` (package.json)
4. `./scripts/test` (executable script)
5. `cargo test` (Rust projects)
6. `pytest` (Python projects)

## Standard Setup (Recommended)

### For Make-based Projects
```makefile
# Makefile
.PHONY: lint test

lint:
	@echo "Running lints..."
	golangci-lint run ./...

test:
	@echo "Running tests..."
	go test ./...
```

### For Node.js Projects
```json
{
  "scripts": {
    "lint": "eslint . --ext .js,.jsx,.ts,.tsx",
    "test": "jest"
  }
}
```

### For Just-based Projects
```just
# justfile
lint:
    @echo "Running lints..."
    cargo clippy -- -D warnings

test:
    @echo "Running tests..."
    cargo test
```

### For Script-based Projects
```bash
#!/usr/bin/env bash
# scripts/lint
set -e
echo "Running lints..."
pylint src/

# scripts/test
set -e
echo "Running tests..."
pytest tests/
```

## Monorepo Support

The hooks work seamlessly with monorepos because they walk up from the edited file:

```
monorepo/
├── Makefile           # Root-level commands
├── services/
│   ├── api/
│   │   ├── Makefile   # Service-specific commands
│   │   └── main.go
│   └── web/
│       ├── package.json
│       └── index.js
└── libs/
    └── shared/
        ├── Makefile
        └── utils.go
```

When editing `services/api/main.go`:
1. First checks `services/api/` for commands
2. Then checks `services/` 
3. Finally checks the monorepo root

## Configuration Options

### Project-Level Config
Create `.claude-hooks-config.sh` in your project root:

```bash
# Use different make targets
export CLAUDE_HOOKS_MAKE_LINT_TARGETS="check lint:all"
export CLAUDE_HOOKS_MAKE_TEST_TARGETS="test:unit test:integration"

# Use different script names
export CLAUDE_HOOKS_SCRIPT_LINT_NAMES="check.sh validate.sh"
export CLAUDE_HOOKS_SCRIPT_TEST_NAMES="test.sh run-tests.sh"

# Disable hooks for this project
export CLAUDE_HOOKS_LINT_ENABLED=false
export CLAUDE_HOOKS_TEST_ENABLED=false
```

### Ignore Patterns
Create `.claude-hooks-ignore` in your project root:

```
# Ignore generated files
*.pb.go
*_gen.go
generated/

# Ignore vendored code
vendor/
node_modules/

# Ignore test files
*_test.go
*.test.js
```

### Inline Ignore
Add to the top of any file to skip hooks:
```go
// claude-hooks-disable
package main
```

## Concurrency Control

The hooks use PID-based locking to prevent issues:

- **No duplicate runs**: If a lint is already running, new requests exit immediately
- **Cooldown period**: After completion, waits 2 seconds before allowing another run
- **Per-workspace locks**: Different projects can run simultaneously

Configure cooldown:
```bash
export CLAUDE_HOOKS_LINT_COOLDOWN=5  # 5 seconds between lint runs
export CLAUDE_HOOKS_TEST_COOLDOWN=3  # 3 seconds between test runs
```

## Performance Tips

### 1. Keep Commands Fast
The hooks have a 10-second timeout by default. Keep your commands quick:

```makefile
# Good: Fast, focused checks
lint:
	golangci-lint run --fast ./...

# Bad: Slow, comprehensive checks
lint:
	golangci-lint run --enable-all ./...
	go mod tidy
	go generate ./...
```

### 2. Use Incremental Checks
Only check what changed:

```makefile
lint:
	@if [ -n "$${CHANGED_FILES}" ]; then \
		golangci-lint run $${CHANGED_FILES}; \
	else \
		golangci-lint run ./...; \
	fi
```

### 3. Configure Timeouts
Adjust for slower commands:
```bash
export CLAUDE_HOOKS_LINT_TIMEOUT=30  # 30 seconds for lint
export CLAUDE_HOOKS_TEST_TIMEOUT=60  # 60 seconds for tests
```

## Debugging

Enable debug output to see what the hooks are doing:
```bash
export CLAUDE_HOOKS_DEBUG=1
```

This shows:
- Which directories are being searched
- Which commands are found
- Why files are skipped
- Lock file operations

## Common Issues

### Commands Not Found
**Problem**: Hooks exit silently, no lint/test runs

**Solution**: Ensure you have standard command names:
- `make lint` not `make check`
- `npm run lint` not `npm run validate`

Or configure custom names in `.claude-hooks-config.sh`

### Commands Run Too Often
**Problem**: Every edit triggers a run

**Solution**: Increase cooldown period:
```bash
export CLAUDE_HOOKS_LINT_COOLDOWN=10
```

### Commands Take Too Long
**Problem**: Hooks timeout before completion

**Solution**: Increase timeout or optimize commands:
```bash
export CLAUDE_HOOKS_LINT_TIMEOUT=30
```

## Best Practices

1. **Use standard names**: `lint` and `test` are automatically found
2. **Keep it fast**: Under 5 seconds is ideal
3. **Clear output**: Make errors obvious and actionable
4. **Project config**: Use `.claude-hooks-config.sh` for project-specific settings
5. **Test locally**: Run `make lint` yourself to ensure it works

## Example Integration Session

```bash
# 1. Check your project has commands
$ make lint
golangci-lint run ./...

$ make test  
go test ./...

# 2. Tell Claude to use hooks
"Please enable hooks for this project and use them to validate all changes"

# 3. Claude edits a file
# Hooks automatically run make lint
# If it fails, Claude sees the error and fixes it
# If it passes, work continues

# 4. Monitor with debug if needed
$ export CLAUDE_HOOKS_DEBUG=1
$ tail -f ~/.claude/logs/hooks.log
```

That's it! The hooks handle the rest automatically.