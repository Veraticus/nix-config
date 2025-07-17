---
allowed-tools: all
description: Verify code quality and fix all issues
---

# Code Quality Check

Fix all issues found during quality verification. Do not just report problems.

## Workflow

1. **Identify** - Run all validation commands
2. **Fix** - Address every issue found
3. **Verify** - Re-run until all checks pass

## Validation Commands

Find and run all applicable commands:
- **Lint**: `make lint`, `golangci-lint run`, `npm run lint`, `ruff check`
- **Test**: `make test`, `go test ./...`, `npm test`, `pytest`
- **Build**: `make build`, `go build ./...`, `npm run build`
- **Format**: `gofmt`, `prettier`, `black`
- **Security**: `gosec`, `npm audit`, `bandit`

## Parallel Fixing Strategy

When multiple issues exist, spawn agents to fix in parallel:
```
Agent 1: Fix linting issues in module A
Agent 2: Fix test failures
Agent 3: Fix type errors
```

## Go-Specific Standards

- Use concrete types, not `interface{}`
- Wrap errors with context
- Add godoc comments
- Use channels for synchronization
- No `time.Sleep()` for coordination

## Success Criteria

All validation commands pass with zero warnings or errors.