#!/usr/bin/env bash
# Trace every line of smart-test.sh execution

cat test-hook-input.json | bash -c '
# Add line numbers to trace output
PS4="+\${LINENO}: "
set -x

# Run the hook
~/.claude/hooks/smart-test.sh 2>&1
' 2>&1 | grep -E "^\+[0-9]+:" | tail -50