# Claude Code Hooks

Automated code quality checks that run after Claude Code modifies files, enforcing project standards with zero tolerance for errors.

## Hooks

### `smart-lint.sh`
Intelligent project-aware linting that automatically detects language and runs appropriate checks:
- **Go**: `gofmt`, `golangci-lint` (enforces forbidden patterns like `time.Sleep`, `panic()`, `interface{}`)
- **Python**: `black`, `ruff` or `flake8`
- **JavaScript/TypeScript**: `eslint`, `prettier`
- **Rust**: `cargo fmt`, `cargo clippy`
- **Nix**: `nixpkgs-fmt`/`alejandra`, `statix`

Features:
- Detects project type automatically
- Respects project-specific Makefiles (`make lint`)
- Smart file filtering (only checks modified files)
- Exit code 2 means issues found - ALL must be fixed
- Configurable deadcode analysis for Go (detects unreachable functions)

#### Failure

```
> Edit operation feedback:
  - [~/.claude/hooks/smart-lint.sh]:
  🔍 Style Check - Validating code formatting...
  ────────────────────────────────────────────
  [INFO] Project type: go
  [INFO] Running Go formatting and linting...
  [INFO] Using Makefile targets

  ═══ Summary ═══
  ❌ Go linting failed (make lint)

  Found 1 issue(s) that MUST be fixed!
  ════════════════════════════════════════════
  ❌ ALL ISSUES ARE BLOCKING ❌
  ════════════════════════════════════════════
  Fix EVERYTHING above until all checks are ✅ GREEN

  🛑 FAILED - Fix all issues above! 🛑
  📋 NEXT STEPS:
    1. Fix the issues listed above
    2. Verify the fix by running the lint command again
    3. Continue with your original task
```
```

#### Success

```
> Task operation feedback:
  - [~/.claude/hooks/smart-lint.sh]:
  🔍 Style Check - Validating code formatting...
  ────────────────────────────────────────────
  [INFO] Project type: go
  [INFO] Running Go formatting and linting...
  [INFO] Using Makefile targets

  👉 Style clean. Continue with your task.
```
```

By `exit 2` on success and telling it to continue, we prevent Claude from stopping after it has corrected
the style issues.

### `ntfy-notifier.sh`
Push notifications via ntfy service for Claude Code events:
- Sends alerts when Claude finishes tasks
- Includes terminal context (tmux/Terminal window name) for identification
- Requires `~/.config/claude-code-ntfy/config.yaml` with topic configuration

## Installation

Automatically installed by Nix home-manager to `~/.claude/hooks/`

## Configuration

### Global Settings
Set environment variables or create project-specific `.claude-hooks-config.sh`:

```bash
CLAUDE_HOOKS_ENABLED=false      # Disable all hooks
CLAUDE_HOOKS_DEBUG=1            # Enable debug output
```

### Per-Project Settings
Create `.claude-hooks-config.sh` in your project root:

```bash
# Language-specific options
CLAUDE_HOOKS_GO_ENABLED=false
CLAUDE_HOOKS_GO_COMPLEXITY_THRESHOLD=30
CLAUDE_HOOKS_PYTHON_ENABLED=false

# Exclude specific test patterns (e.g., E2E tests requiring special context)
CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS="e2e,integration_test"

# See example-claude-hooks-config.sh for all options
```

### Excluding Files

#### Using .claude-hooks-ignore
Create `.claude-hooks-ignore` in your project root to exclude files from all hooks. This file uses gitignore syntax with support for:
- Glob patterns (`*.pb.go`, `*_generated.go`)
- Directory patterns (`vendor/**`, `node_modules/**`)
- Specific files (`legacy/old_api.go`)

**Example .claude-hooks-ignore:**
```gitignore
# Generated files that shouldn't be linted
*.pb.go
*_generated.go
*.min.js
dist/**
build/**

# Third-party code
vendor/**
node_modules/**

# Files with special formatting
migrations/*.sql
testdata/**
*.golden

# Temporary exclusions (document why!)
# TODO: Remove after migration (ticket #123)
legacy/old_api.go
```

Create `.claude-hooks-ignore` in your project root using gitignore syntax:
```gitignore
# Generated code
*.pb.go
*_generated.go

# Vendor dependencies
vendor/**
node_modules/**

# Legacy code being refactored
legacy/**
```

See `example-claude-hooks-ignore` for a comprehensive template with detailed explanations.

#### Inline Exclusions
Add a comment to the first 5 lines of any file to skip it:
```go
// claude-hooks-disable - Legacy code, will be removed in v2.0
package old
```

Language-specific comments:
- Go: `// claude-hooks-disable`
- Python: `# claude-hooks-disable`
- JavaScript: `// claude-hooks-disable`
- Rust: `// claude-hooks-disable`
- Tilt: `# claude-hooks-disable`

**Always document WHY** the file is excluded!

#### Important: Use Exclusions Sparingly!
The goal is 100% clean code. Only exclude:
- **Generated code** - Protocol buffers, code generators
- **Vendor directories** - Third-party code you don't control
- **Test fixtures** - Intentionally malformed code for testing
- **Database migrations** - Often have different formatting standards
- **Legacy code** - Only with a clear migration plan

**Never exclude** to avoid fixing issues:
- ❌ Your source code
- ❌ Test files (they should meet standards too)
- ❌ New features you're writing
- ❌ Code you're too lazy to fix

The `.claude-hooks-ignore` is for code you **can't** fix, not code you **won't** fix.

## Usage

```bash
./smart-lint.sh           # Auto-runs after Claude edits
./smart-lint.sh --debug   # Debug mode
```

### Exit Codes
- `0`: All checks passed ✅
- `1`: General error (missing dependencies)
- `2`: Issues found - must fix ALL

## Dependencies

Hooks work best with these tools installed:
- **Go**: `golangci-lint`
- **Python**: `black`, `ruff`
- **JavaScript**: `eslint`, `prettier` 
- **Rust**: `cargo fmt`, `cargo clippy`
- **Nix**: `nixpkgs-fmt`, `alejandra`, `statix`

Hooks gracefully degrade if tools aren't installed.
