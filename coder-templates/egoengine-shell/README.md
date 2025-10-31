# egoengine Base Image Template

This template provisions a Docker workspace that runs the egoengine base image directly, without Envbuilder. It is useful for general-purpose shells or ad-hoc tasks that only require the baked Home Manager profile.

## Variables

| Name | Description |
| --- | --- |
| `docker_socket` (optional) | Override the Docker daemon URI if the provisioner is not using the default socket. |
| `workspace_image` | OCI image to run. Default: `ghcr.io/veraticus/nix-config/egoengine:latest`. Point this to the image published by the CI workflow. |
| `op_service_account_token` (sensitive) | 1Password Service Account token. Provide via Coder Terraform variables or another secret mechanism. |

## Behaviour

- The workspace volume is mounted at `/home/joshsymonds` so the entire home directory persists between sessions.
- During startup the agent fetches `auth.json` from 1Password (if the token is supplied), locks it to `0600`, runs `codex auth me`, and then calls `ee sync --quiet` to mirror eligible 1Password document items into the workspace home directory.

```sh
set -euo pipefail
mkdir -p ~/.codex
umask 077
op read 'op://egoengine/Codex Auth/auth.json' > ~/.codex/auth.json || true
chmod 600 ~/.codex/auth.json || true
codex auth me || rm -f ~/.codex/auth.json || true
if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -x "$HOME/.local/bin/ee" ]; then
  "$HOME/.local/bin/ee" sync --quiet || true
fi
```

- Document items named `personal`, `work`, or `service-account` are skipped; everything else is written into `$HOME` (with `home/` prefixes mapping to the corresponding relative path).

## Notes

- Configure the `workspace_image` to match the GHCR repository populated by `.github/workflows/build-base.yml`.
- The template sets only the coder agent token in the container environment; all other secrets flow through the agent's environment to avoid storing them in Docker labels.
- Use `ee secret <relative-path>` inside the workspace to push files back to the `egoengine` vault (they are stored as 1Password document items named `home/<relative-path>`).
