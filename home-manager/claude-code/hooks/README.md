# Coding-agent hooks

Hook scripts deployed verbatim to `~/.claude/hooks/`
by `../default.nix` (`mkClaudeFiles`), wired up in `../settings.json`:

- `aws-profile-mirror.sh` — `PostToolUse`/`Bash` hook.

## Notifications live in Steward

The canonical sender is `steward notify` from
[github.com/joshsymonds/steward](https://github.com/joshsymonds/steward).
Claude wires `steward notify --harness claude-code` directly in
`../settings.json` for root `Stop`, `Notification` with the explicit matcher
`permission_prompt|agent_needs_input|elicitation_dialog|elicitation_url_dialog`,
and `SessionEnd` cleanup. The existing `usage-summary-refresh.sh` Stop hook runs
beside Steward. Pi integrates separately at the root TUI `agent_settled` event;
there is no Codex integration.

Eligibility is deterministic from native event identity and structural
completion, goal, continuation, and root-context state. Eligible completions
may use one optional shared, sessionless composition to produce the body and a
short label; failure keeps the deterministic body and current label/project.
Missing or unreliable native completion identity fails open through a bounded
current-hook fallback. Delivery deduplication uses atomic in-memory claims.
There is no judge, watchdog, or task-pending gate.

The sender reads the agenix paths from `STEWARD_NTFY_URL_FILE` and
`STEWARD_NTFY_TOKEN_FILE`. Decisions are appended by default to
`${XDG_STATE_HOME:-~/.local/state}/steward/notify/notify-decisions.jsonl`; read
that log first when a ping or silence looks wrong. The subscriber contract in
`home-manager/ntfy-notify/` remains: blocked = priority 5 + `question`, while
done/info = priority 4/3 + `white_check_mark`.
