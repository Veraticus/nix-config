egoengine: Coder-Based Devspaces Architecture and Migration Plan

Summary

- Replace devspaces with Coder OSS on a new control-plane host named egoengine.
- Workspaces run as user joshsymonds, with Home Manager and development tools baked into a Nix-built base OCI image.
- Per-project environments layer on top via Devcontainers built by Envbuilder with a registry cache (Option A).
- Secrets are fetched at workspace startup from 1Password Cloud using a scoped Service Account token; no host mounts.
- Initial deployment via Docker Compose on egoengine; optional future migration to Kubernetes.

Scope and Non‑Goals

- In scope: image build pipeline, Coder deployment, workspace templates (Docker provider), secrets ingestion, and developer workflow.
- Out of scope (for initial phase): writing all Terraform/Nix code in this document; this is a blueprint for implementation.

Naming and Identity

- Control-plane hostname: egoengine (distinct from vermissian).
- Workspace user: joshsymonds (not coder). Home directory /home/joshsymonds.

High‑Level Architecture

- Base Dev Image
  - Nix flake produces an OCI image with Home Manager for joshsymonds, shell/prompt, Neovim, hooks, and dev tools.
  - Built and published to GHCR on every push to nix-config.

- Per‑Project Layering (Option A)
  - Each project repo includes devcontainer.json (and optionally a tiny Dockerfile) that uses the base image and adds project-specific SDKs/deps.
  - Coder uses Envbuilder to build/run the devcontainer, leveraging a registry cache for fast rebuilds.

- Coder Deployment
  - Phase 1: Docker Compose on egoengine; Docker provider templates.
  - Phase 2 (optional): Kubernetes via the provided Helm chart; PVCs for storage; ImagePullSecrets for private registries.

- Secrets Management
  - 1Password Service Account restricted to a dedicated vault (e.g., egoengine).
  - Workspaces receive OP_SERVICE_ACCOUNT_TOKEN via Coder template env; at startup, use op CLI to fetch/write files such as ~/.codex/auth.json.
  - No host mounts; portable across Docker and Kubernetes.

Repository Impact

- docs/: This design file.
- Nix: Add a flake package output `egoengine-dev-base-oci` that builds the base OCI image tagged ghcr.io/veraticus/nix-config/egoengine:<tag>.
- Coder templates: Add Docker Envbuilder template configured for joshsymonds and GHCR cache.
- CI: GitHub Actions job to build and push base image on push to main; optional signing (cosign).

Components and Design Details

1) Base Dev Image (Nix → OCI)

- Goals
  - Exactly reproduce joshsymonds Home Manager environment, prompt, Neovim config, hooks, and dev tools in a deterministic OCI image.
  - Publish on every push; pin tag in templates for reproducibility.

- Build strategy
  - Use dockerTools (or nix2container) to assemble an OCI image from your flake Home Manager configuration for joshsymonds.
  - Create user joshsymonds (UID/GID stable across hosts), set HOME to /home/joshsymonds, and set the login shell.
  - Include op (1Password CLI) preinstalled.
  - Local validation: `nix build .#egoengine-dev-base-oci` followed by `docker load < result`.

- Tagging and publishing
  - Tag scheme: ghcr.io/veraticus/nix-config/egoengine:<flakeRev> (and a moving ghcr.io/veraticus/nix-config/egoengine:latest for convenience).
  - Push via CI; optionally sign via cosign.

- CI outline
  - `nix build .#egoengine-dev-base-oci`
  - `docker load < result`
  - `docker tag` the loaded image as ghcr.io/veraticus/nix-config/egoengine:<rev> and ghcr.io/veraticus/nix-config/egoengine:latest
  - `docker push` both tags using the repository’s built-in `GITHUB_TOKEN`

2) Coder Deployment (egoengine)

- Phase 1: Docker Compose
  - Use the compose file from Coder for a local deployment and adapt for egoengine.
  - Reference: reference/coder/compose.yaml:1
  - Required env:
    - CODER_ACCESS_URL=https://egoengine.<domain>
    - CODER_PG_CONNECTION_URL=postgres://...
  - Mount /var/run/docker.sock for Docker provider templates.
  - DNS: egoengine.<domain> → host IP; terminate TLS at reverse proxy if not using try.coder.app.

- Phase 2: Kubernetes (optional)
  - Install via Helm (reference/coder/helm/coder).
  - Use PVCs for workspace home; ImagePullSecrets for GHCR; NetworkPolicies for isolation.
  - Avoid hostPath volumes; use CSI-backed storage and K8s Secrets.

3) Workspace Templates

- Strategy
  - Docker provider (Phase 1) with two flavors stored under `coder-templates/`:
    - `egoengine-shell`: runs ghcr.io/veraticus/nix-config/egoengine:<tag> as the workspace image for general shells.
    - `egoengine-envbuilder`: uses Envbuilder to build and run a per-project devcontainer using the base image and registry cache.

- Template specifics (Docker)
  - Workspace user and home
    - coder_agent.dir = "/home/joshsymonds"
    - docker_container volumes: persistent Docker volume mounted at container_path = "/home/joshsymonds"
    - Reference: reference/coder/examples/templates/docker/main.tf:174
  - IDE modules
    - code-server and JetBrains modules configured with folder = "/home/joshsymonds"
    - Reference: reference/coder/examples/templates/docker/main.tf:124
  - Envbuilder devcontainer template (`coder-templates/egoengine-envbuilder/`)
    - Based on reference/coder/examples/templates/docker-envbuilder/main.tf:123
    - Parameters:
      - repo (URL) or custom_repo_url
      - fallback_image (ghcr.io/veraticus/nix-config/egoengine:<tag> recommended)
      - cache_repo (GHCR path), optional dockerconfig for auth
    - Host gateway mapping for 127.0.0.1 edge cases already included in examples.

- Template specifics (Kubernetes, optional later)
  - Use kubernetes-devcontainer example; set PVCs and ImagePullSecrets.
  - Reference: reference/coder/examples/templates/kubernetes-devcontainer/main.tf:150

4) Secrets Management via 1Password Service Account

- Why this approach
  - No host mounts; same UX for Docker and K8s; central single source of truth.
  - Service Account token is injected as a secret env var; dev machines read only from a dedicated vault.

- Vault and Service Account
  - Create vault egoengine.
  - Create a Service Account scoped read-only to that vault.
  - Store OP_SERVICE_ACCOUNT_TOKEN in CI/provisioner secrets, not in code or template parameters.

- Secret modeling
  - For Codex CLI, keep an item named “Codex Auth” with a file field or document attachment auth.json.
  - Update this file whenever you refresh locally.

- Workspace startup ingestion (idempotent)
  - Ensure op is installed (base image).
  - Template env:
    - OP_SERVICE_ACCOUNT_TOKEN (sensitive)
  - coder_agent.startup_script (POSIX; minimal):
    - set -euo pipefail
    - mkdir -p ~/.codex && umask 077
    - op read 'op://egoengine/Codex Auth/auth.json' > ~/.codex/auth.json || true
    - chmod 600 ~/.codex/auth.json || true
    - Optional: codex auth me || rm -f ~/.codex/auth.json

- Security considerations
  - Do not use template parameters for secrets; they display in cleartext.
    - Reference: reference/coder/docs/admin/security/secrets.md:25
  - Keep Service Account scoped and rotate regularly.

5) CI/CD

- nix-config CI
  - Build and push base image on every push to main.
  - Optionally cosign the image.
  - Cache Nix store to speed up builds.

- Template publishing
  - Iterate templates in-repo and import into Coder via UI/CLI.
  - Optionally use coderd Terraform provider to GitOps template versions from this repo.

6) Developer Workflow

- Create a workspace from the Devcontainer template; select the repo.
- Envbuilder builds the devcontainer from the base image; registry cache accelerates rebuilds.
- On start, secrets are fetched from 1Password to ~/.codex.
- Use code-server/JetBrains modules, or connect external IDE via Coder extension/Connect.
- Persistent home volume preserves environment and tokens across restarts; updated tokens propagate on next start.

7) Security and Compliance

- Secrets
  - Inject via env or K8s Secrets; never via template parameters.
  - Avoid hostPath volumes on K8s; prefer PVCs.
  - Reference: reference/coder/docs/admin/infrastructure/validated-architectures/index.md:280

- Access and TLS
  - Enforce OIDC/SSO to Coder; serve CODER_ACCESS_URL over TLS.
  - Keep OP_SERVICE_ACCOUNT_TOKEN only in CI/provisioner secrets or K8s Secret.

- Filesystem
  - Lock permissions: auth.json 600; HOME owned by joshsymonds.

8) Observability

- Use coder_agent metadata blocks to show CPU, RAM, disk usage in UI.
  - References: reference/coder/examples/templates/docker/main.tf:57
- Logs: /tmp/coder-agent.log in workspace and Coder server logs.
- Validation: after startup, verify ~/.codex/auth.json exists and codex CLI authentication succeeds.

9) Risks and Mitigations

- Token staleness
  - Mitigation: fetch on start; validate; rely on re-pull when restarting; optional periodic fetch inside workspace.

- Base image drift
  - Mitigation: pin tag in templates; CI publishes on push; periodic cleanups.

- Registry auth
  - Mitigation: configure dockerconfig for GHCR in Envbuilder (if cache is private); or keep cache public.

- Vendor lock to Docker provider
  - Mitigation: design remains portable; K8s template provided as second path using same secrets flow.

10) Implementation Plan

- Phase 0: Naming and access
  - DNS: egoengine.<domain> → host IP.
  - TLS: terminate for CODER_ACCESS_URL.

- Phase 1: Base image and CI
  - Add flake target dev-base-oci with user joshsymonds, op CLI installed.
  - Add GHCR push workflow; document tags.
  - Acceptance: image pulls and runs; login shell, Neovim, hooks present.

- Phase 2: Coder on egoengine (Docker Compose)
  - Launch Coder via compose; configure Postgres; set CODER_ACCESS_URL.
  - Acceptance: Coder UI accessible; can create a basic Docker workspace.

- Phase 3: Devcontainer template with Envbuilder
  - Create Docker Envbuilder template pinned to base; set cache_repo to GHCR.
  - Set coder_agent.dir=/home/joshsymonds, volume, IDE modules.
  - Acceptance: select repo → workspace builds and opens; base customizations visible.

- Phase 4: 1Password Service Account secrets
  - Create vault egoengine; scope Service Account read-only.
  - Inject OP_SERVICE_ACCOUNT_TOKEN via template env (sensitive) or K8s Secret (future).
  - Add startup ingestion snippet to write ~/.codex/auth.json; validate with codex CLI.
  - Acceptance: token ingested on start; refreshed item in 1Password is picked up on restart.

- Phase 5 (optional): Kubernetes
  - Deploy Coder via Helm; convert template to K8s devcontainer variant; PVCs; ImagePullSecrets.
  - Acceptance: parity with Docker flow; secrets flow unchanged.

11) Open Questions

- Image size vs. startup time: should some heavy SDKs move to per-project layers only?
- Cache repo visibility: public vs private GHCR for Envbuilder cache.
- Scheduled re-fetch in long-running workspaces: add a daily cron, or rely on restarts?

Appendix: Reference Pointers

- Coder Docker compose: reference/coder/compose.yaml:1
- Docker template (volumes, IDE modules, metadata): reference/coder/examples/templates/docker/main.tf:124
- Docker Envbuilder template: reference/coder/examples/templates/docker-envbuilder/main.tf:123
- K8s devcontainer: reference/coder/examples/templates/kubernetes-devcontainer/main.tf:150
- Secrets guidance: reference/coder/docs/admin/security/secrets.md:25
- Avoid hostPath volumes: reference/coder/docs/admin/infrastructure/validated-architectures/index.md:280
