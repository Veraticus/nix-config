# egoengine Docker Envbuilder Template

This template provisions a Coder workspace that layers project-specific devcontainers on top of the egoengine base image. It relies on [Envbuilder](https://github.com/coder/envbuilder) to build the devcontainer and persists the entire home directory at `/home/joshsymonds`.

## Parameters

| Name | Description |
| --- | --- |
| **Repository** | Predefined repositories or `Custom` to supply your own URL. |
| **Repository URL (custom)** | Used when `Custom` is selected above. |
| **Fallback Image** | OCI image that boots the workspace if the devcontainer build fails. Set this to the published base image, e.g. `ghcr.io/veraticus/nix-config/egoengine:<rev>`. |
| **Devcontainer Builder** | Envbuilder image to use for builds. Pin to a specific tag. |
| **Cache Registry** | Optional registry (e.g. GHCR) used as an Envbuilder cache. Leave blank to disable pushing/pulling cache layers. |
| **Cache Registry Docker Config Path** | Optional path on the provisioner host to a `config.json` with credentials for the cache registry. |

Additional Terraform variables:

- `docker_socket` – override the Docker socket URI. \
- `op_service_account_token` (sensitive) – 1Password Service Account token injected into the workspace. Set this via Coder Terraform variables or your preferred secrets store.

## Secrets & Authentication

- The template expects the 1Password token in the `OP_SERVICE_ACCOUNT_TOKEN` environment variable. Provide it through the `op_service_account_token` Terraform variable (never via template parameters – they display in plain text).
- At startup the agent:
  ```sh
  set -euo pipefail
  mkdir -p ~/.codex && umask 077
  op read 'op://egoengine/Codex Auth/auth.json' > ~/.codex/auth.json || true
  chmod 600 ~/.codex/auth.json || true
  codex auth me || rm -f ~/.codex/auth.json || true
  # Mirror 1Password document items into the workspace
  if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -x "$HOME/.local/bin/ee" ]; then
    "$HOME/.local/bin/ee" sync --quiet || true
  fi
  ```
  Ensure the vault path (`egoengine/Codex Auth/auth.json`) matches the item stored in 1Password.
  Any document item in the `egoengine` vault whose title is not `personal`, `work`, or `service-account`
  is mirrored into the workspace `$HOME` via `ee sync --quiet`. Titles beginning with `home/` map to the corresponding
  relative path (e.g. `home/.ssh/id_ed25519` → `~/.ssh/id_ed25519`). Use `ee secret <path>` to upload
  files back into 1Password.

## Persistent Home Directory

The workspace volume is mounted at `/home/joshsymonds`, giving every devcontainer build the baked Home Manager environment while persisting user state across workspace restarts.

## Cache Registry

To enable build caching:

1. Populate **Cache Registry** with a registry URL (e.g. `ghcr.io/<owner>/envbuilder-cache`).
2. If authentication is required, provide a path to a Docker `config.json` via **Cache Registry Docker Config Path**. The provisioner must have read access to this file.
3. Ensure the registry is reachable from the workspace host.

## Customisation Notes

- Update the default fallback image to point at the GHCR repository created by `.github/workflows/build-base.yml`.
- The Envbuilder workdir is `/home/joshsymonds`, keeping repo checkouts inside the persistent home directory.
- The template intentionally omits bundled IDE backends; install editors directly inside the devcontainer when needed.
