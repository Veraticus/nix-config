# The ChatGPT/Codex subscription route set patchbay publishes when
# codexUpstream is enabled: route key -> upstream model id.
#
# Split out of home-manager/patchbay/default.nix so the route keys have one
# home. The gambit rung agents in home-manager/claude-code point at these keys
# by name, and tests/gambit-rung-agents.nix imports this file to prove no rung
# names a route patchbay does not publish.
#
# Every id below is confirmed present in the codex channel's /v1/models.
{
  # GPT-6 Astra: the Claude Code default model on Codex-upstream hosts
  # (home-manager/claude-code/settings.json names this key). Effort rides
  # Claude Code's output_config.effort, which CLIProxyAPI translates to the
  # Responses reasoning effort — verified 2026-09-05 by comparing reasoning
  # tokens at low vs xhigh, same step as the "(xhigh)" model-id suffix.
  "chatgpt/astra" = "gpt-6-astra";
  # The capable GPT-5.6 tier and the top of the gambit ladder.
  "chatgpt/sol" = "gpt-5.6-sol";
  # The fast tier for haiku-slot work (summaries, small tool calls).
  "chatgpt/luna" = "gpt-5.6-luna";
  # The middle rung of the gambit ladder.
  "chatgpt/terra" = "gpt-5.6-terra";
}
