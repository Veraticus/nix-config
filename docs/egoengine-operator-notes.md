# egoengine Operator Notes

## Declarative Deployment on Vermissian

Coder now runs declaratively on `vermissian` via `modules/services/egoengine-coder.nix`. The module provisions PostgreSQL, pulls the official container with Podman, and manages secrets through agenix.

1. Add your machine and user recipients to `secrets/keys.nix` (run this from the repo on the box you want to trust):
   ```sh
   ./scripts/agenix-add-recipient.py --host vermissian
   ```
   This reads `/etc/age/recipients.txt` for the host key and the operator key from `~/.config/agenix/keys.pub` (generated automatically from your SSH key).
2. Populate the secrets:
   ```sh
   agenix -e secrets/coder-db-password.age    # CODER_DB_PASSWORD=...
   agenix -e secrets/coder-env.age            # CODER_PG_CONNECTION_URL=..., CODER_PROVISIONER_PSK=..., CODER_ADMIN_TOKEN=...
   ```
   `CODER_ADMIN_TOKEN` is used by the CLI when pushing templates manually.
3. Deploy the host:
   ```sh
   make update HOST=vermissian
   # or: sudo nixos-rebuild switch --flake .#vermissian
   ```
4. Verify health:
   ```sh
   curl http://127.0.0.1:7080/healthz
   coder login https://vermissian:7080
   ```
5. After creating the first administrator (either in the UI or with `coder login --first-user-*`), push the templates manually from the host. The Coder CLI is already available, so run:
   ```sh
   export CODER_ADMIN_TOKEN=…
   export CODER_SESSION_TOKEN="$CODER_ADMIN_TOKEN"
   export CODER_URL=http://127.0.0.1:7080

   coder templates push \
     --yes \
     --name egoengine-envbuilder \
     coder-templates/egoengine-envbuilder

   coder templates push \
     --yes \
     --name egoengine-shell \
     coder-templates/egoengine-shell
   ```
   Add `--provisioner-tag <tag>` if you need to target a specific provisioner pool.

The legacy Docker Compose flow below remains available for ad-hoc testing but should no longer be required for production.

## Bringing up Coder via Docker Compose

## Supplying the 1Password Service Account Token

Templates expect the token via `OP_SERVICE_ACCOUNT_TOKEN`. When applying Terraform or importing templates, export it as:

```sh
export TF_VAR_op_service_account_token="$(op read 'op://egoengine/Coder Service Account/token')"
```

For GitOps with the coderd provider, store the token in your secret manager and set the variable in the automation context rather than hardcoding it in Terraform.

## Maintaining `codex` Authentication Material

- The workspace startup script reads `op://egoengine/Codex Auth/auth.json`.
- Update `auth.json` in 1Password whenever the Codex CLI token rotates.
- Ensure the item remains readable by the scoped service account; permissions are not inherited automatically when moving items between vaults.

## Publishing Coder Templates

After the templates are registered (see the declarative deployment section), you can create workspaces via the UI or:

```sh
coder workspace create --template egoengine-envbuilder my-workspace
```

## Referencing the Base Image in devcontainer.json

Point project devcontainers at the published base image to inherit the Home Manager environment:

```json
{
  "image": "ghcr.io/veraticus/nix-config/egoengine:<rev>",
  "runArgs": ["--user", "joshsymonds"]
}
```

For reproducibility, use the immutable `<git-sha>` tag produced by the CI workflow rather than `latest`.
