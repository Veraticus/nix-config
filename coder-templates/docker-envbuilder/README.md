# Docker Envbuilder Template

This template provisions a Coder workspace that layers project-specific devcontainers on top of a user-supplied base image. It relies on [Envbuilder](https://github.com/coder/envbuilder) to build the devcontainer and persists the entire home directory at `/home/joshsymonds`.

## Parameters

| Name | Description |
| --- | --- |
| **Repository URL** | Required Git repository cloned and built with Envbuilder. |
| **Fallback Image** | Required OCI image that boots the workspace if the devcontainer build fails. Provide the tag you want Envbuilder to fall back to. |
| **Devcontainer Builder** | Envbuilder image to use for builds. Pin to a specific tag. |
| **Cache Registry** | Optional registry (e.g. GHCR) used as an Envbuilder cache. Leave blank to disable pushing/pulling cache layers. |
| **Cache Registry Docker Config Path** | Optional path on the provisioner host to a `config.json` with credentials for the cache registry. |

Additional Terraform variables:

- `docker_socket` – override the Docker socket URI.

## Persistent Home Directory

The workspace volume is mounted at `/home/joshsymonds`, keeping state across workspace restarts. Update `workspace_home` in the template if you later change the image user or prefer stateless sessions.

## Secret Cleanup

Shutdown cleanup is opt-in. If the workspace environment defines:

- `WORKSPACE_SECRET_MANIFEST` – path to a newline-delimited list of files or directories (relative to `$HOME` unless absolute). Each entry is removed recursively when the workspace stops.
- `WORKSPACE_SECRET_CLEAN_CMD` – optional shell command executed via `sh -c` after manifest processing (useful for custom scrubs).

The egoengine image exports `WORKSPACE_SECRET_MANIFEST=~/.local/state/ee/synced-files`, and `ee sync` records every mirrored document plus `~/.aws` so the stop hook can delete them. Other images can participate by writing their own manifest or command; if neither variable is set, the cleanup hook exits without action.

## Cache Registry

To enable build caching:

1. Populate **Cache Registry** with a registry URL (e.g. `ghcr.io/<owner>/envbuilder-cache`).
2. If authentication is required, provide a path to a Docker `config.json` via **Cache Registry Docker Config Path**. The provisioner must have read access to this file.
3. Ensure the registry is reachable from the workspace host.

## Customisation Notes

- Select the fallback image that matches your published base image; pin to an immutable tag for reproducibility.
- The Envbuilder workdir is `/home/joshsymonds`; adjust `workspace_home` in the Terraform if your image uses a different home path.
- The template intentionally omits bundled IDE backends; install editors directly inside the devcontainer when needed.
