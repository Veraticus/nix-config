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
- During startup the agent fetches `auth.json` from 1Password (if the token is supplied), locks it to `0600`, and runs `codex auth me`, removing the file if authentication fails.

```sh
set -euo pipefail
mkdir -p ~/.codex
umask 077
op read 'op://egoengine/Codex Auth/auth.json' > ~/.codex/auth.json || true
chmod 600 ~/.codex/auth.json || true
codex auth me || rm -f ~/.codex/auth.json || true
```

- code-server and JetBrains desktop integrations default to `/home/joshsymonds`.

## Notes

- Configure the `workspace_image` to match the GHCR repository populated by `.github/workflows/build-base.yml`.
- The template sets only the coder agent token in the container environment; all other secrets flow through the agent's environment to avoid storing them in Docker labels.
