---
allowed-tools: all
description: Synthesize a complete prompt by combining next.md with your arguments
---

# Prompt Synthesizer

Create a complete prompt by combining:
1. The next.md template from ~/.claude/commands/next.md
2. User's task: $ARGUMENTS

## Task

1. Read next.md command file
2. Replace `$ARGUMENTS` placeholder with the actual task
3. Output the complete prompt in a code block

## Output Format

```
[Complete synthesized prompt ready to copy]
```

## Synthesis Guidelines

- Preserve the workflow and requirements from next.md
- If task mentions specific languages, emphasize those sections
- For complex tasks, highlight "ultrathink" and "multiple agents"
- For refactoring, emphasize "delete old code" requirements
- Keep all critical requirements (hooks, linting, testing)

Begin synthesis now.