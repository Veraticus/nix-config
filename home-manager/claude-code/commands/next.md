---
allowed-tools: all
description: Execute production-quality implementation
---

# Production Implementation

Implement: $ARGUMENTS

## Required Workflow

1. **Research** - "Let me research the codebase and create a plan before implementing"
2. **Plan** - Present approach for validation
3. **Implement** - Build with continuous validation

For complex architecture decisions: "Let me ultrathink about this architecture"

For tasks with independent parts: Spawn multiple agents in parallel

## Implementation Standards

### Code Evolution
- Replace old code entirely when refactoring
- No versioned function names (processV2, handleNew)
- No compatibility layers or migration code
- This is a feature branch - implement the final solution directly

### Quality Checkpoints
- Run linters after every 3 file edits
- Validate each component works before proceeding
- Run full test suite before completion
- Fix linter warnings immediately when found

### Go-Specific Requirements
- Use concrete types, not `interface{}`
- Simple error handling with standard patterns
- Channels for synchronization, not `time.Sleep()`
- Follow standard project layout (cmd/, internal/, pkg/)
- Document why decisions were made
- Add godoc comments for exported symbols

### General Requirements
- Follow existing codebase patterns
- Use language-appropriate linters at maximum strictness
- Write tests for business logic
- Ensure end-to-end functionality

## Completion Criteria

- All linters pass with zero warnings
- All tests pass (including race detection)
- Feature works in realistic scenarios
- No TODOs or temporary code remains