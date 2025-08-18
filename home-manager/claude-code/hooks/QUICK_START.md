# Quick Start Guide

Get Claude Code hooks running with your project in under 5 minutes!

## 🎯 What You Get

- **Automatic linting** after every file edit
- **Automatic testing** after every file edit  
- **Clear feedback** when something fails
- **Smart concurrency** - no duplicate runs

## 📋 Prerequisites

Your project needs ONE of these:
- `make lint` and `make test` commands
- `npm run lint` and `npm run test` scripts
- `just lint` and `just test` recipes
- `./scripts/lint` and `./scripts/test` executables

Don't have them? See examples below!

## 🚀 Instant Setup

### Step 1: Verify Your Commands Work
```bash
# In your project directory:
make lint   # Should run your linters
make test   # Should run your tests
```

### Step 2: That's It!
The hooks are already installed and will automatically find your commands.

When Claude edits a file:
1. Hooks walk up from the file's directory
2. Find your project's lint/test commands
3. Run them and show results
4. Block further edits if they fail

## 📦 No Commands Yet? Add Them!

### For Go Projects
Create a `Makefile`:
```makefile
.PHONY: lint test

lint:
	golangci-lint run ./...

test:
	go test ./...
```

### For JavaScript/TypeScript Projects
Add to `package.json`:
```json
{
  "scripts": {
    "lint": "eslint .",
    "test": "jest"
  }
}
```

### For Python Projects
Create `scripts/lint`:
```bash
#!/usr/bin/env bash
set -e
ruff check .
# or: flake8 .
# or: pylint src/
```

Create `scripts/test`:
```bash
#!/usr/bin/env bash
set -e
pytest
```

Make them executable:
```bash
chmod +x scripts/lint scripts/test
```

### For Rust Projects
Create a `Makefile`:
```makefile
.PHONY: lint test

lint:
	cargo clippy -- -D warnings

test:
	cargo test
```

## 🎮 Test It Out

Ask Claude to edit a file and watch the hooks in action:

```
"Add a new function to calculate the factorial of a number"
```

You'll see:
- ✅ `👉 Lints pass. Continue with your task.` - Everything's good!
- ❌ `⛔ BLOCKING: Must fix ALL lint failures` - Claude needs to fix issues

## 🔧 Optional: Configure Behavior

### Disable for a Project
Create `.claude-hooks-config.sh` in project root:
```bash
export CLAUDE_HOOKS_LINT_ENABLED=false
export CLAUDE_HOOKS_TEST_ENABLED=false
```

### Ignore Specific Files
Create `.claude-hooks-ignore`:
```
generated/
*.pb.go
vendor/
node_modules/
```

### Adjust Timing
```bash
# Wait longer between runs (default: 2 seconds)
export CLAUDE_HOOKS_LINT_COOLDOWN=5
export CLAUDE_HOOKS_TEST_COOLDOWN=5

# Allow more time for slow commands (default: 10 seconds)
export CLAUDE_HOOKS_LINT_TIMEOUT=30
export CLAUDE_HOOKS_TEST_TIMEOUT=30
```

## 🐛 Debugging

See what's happening:
```bash
export CLAUDE_HOOKS_DEBUG=1
```

Watch it work:
```bash
# In one terminal:
tail -f /tmp/claude-hook-*.lock

# Ask Claude to edit files
# Watch the lock files update
```

## 💡 Pro Tips

1. **Keep it fast** - Commands should complete in < 5 seconds
2. **Clear errors** - Make error messages actionable
3. **Use standards** - `make lint` and `make test` just work
4. **Test locally** - If `make lint` works for you, it works for Claude

## 🆘 Troubleshooting

### Nothing happens when Claude edits files
- Check you have `make lint` or equivalent
- Try `export CLAUDE_HOOKS_DEBUG=1` to see details
- Verify commands work when you run them manually

### Hooks run too often
- Increase cooldown: `export CLAUDE_HOOKS_LINT_COOLDOWN=10`
- The default 2-second cooldown prevents rapid re-runs

### Commands timeout
- Increase timeout: `export CLAUDE_HOOKS_LINT_TIMEOUT=30`
- Or make your commands faster (use `--fast` flags, etc.)

### Different command names
Create `.claude-hooks-config.sh`:
```bash
# Your commands are "make check" and "make verify"
export CLAUDE_HOOKS_MAKE_LINT_TARGETS="check"
export CLAUDE_HOOKS_MAKE_TEST_TARGETS="verify"
```

## 🎉 Success!

You now have automatic code quality checks! Claude will:
- Run your lints after editing files
- Run your tests after editing files
- Fix any issues before continuing
- Never submit broken code

Happy coding! 🚀