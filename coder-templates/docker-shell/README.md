# Docker Shell Template

This template provisions a Docker-based Coder workspace that runs a user-supplied image directly (no Envbuilder layer). It is useful for general-purpose shells or lightweight tasks that only require the pre-built image.

## Parameters

| Name | Description |
| --- | --- |
| `docker_socket` (optional) | Override the Docker daemon URI if the provisioner is not using the default socket. |
| `workspace_image` | Required OCI image to run for the workspace. Provide the tag you want Coder to start. |
| `entrypoint_shell` | Shell used to launch the Coder agent script. Default: `sh`. Override if your image lacks POSIX `sh`. |

## Behaviour

- The workspace volume is mounted at `/home/joshsymonds` so the entire home directory persists between sessions.
- Secret cleanup follows the same contract as the Envbuilder template: set `WORKSPACE_SECRET_MANIFEST` to a newline-delimited manifest of paths to remove (relative to `$HOME` by default) and optionally `WORKSPACE_SECRET_CLEAN_CMD` for extra teardown. The egoengine image and `ee sync` populate these automatically, but other images can opt in by exporting the variables.

## Notes

- Set `workspace_image` to the tag published by your CI workflow (e.g. a GHCR image).
- Adjust the home path in `workspace_home` if your image uses a different user.
- Install additional tools via your image build process; the template only wires the container lifecycle.
