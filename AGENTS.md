# Repository Guidelines

## Project Structure & Module Organization
- Nix flake entrypoints: `flake.nix`, `flake.lock`.
- Hosts (NixOS/Darwin): `hosts/<hostname>/` and `home-manager/hosts/<hostname>.nix`.
- User config: `home-manager/` (apps, shells, editors), reusable `modules/` and `overlays/`.
- Custom packages: `pkgs/<name>/default.nix` with shared `pkgs/default.nix` aggregator.
- Docs and references: `docs/`, `reference/`. Top-level `README.md` for overview.

## Build, Test, and Development Commands
- `make lint` — Run Nix linters (`statix`, `deadnix`) and hook linters when applicable.
- `make test` — Run hook tests (ShellSpec fixtures under `home-manager/claude-code/hooks/spec`).
- `make check` — Lint + test; default target.
- `make update` — Rebuild and switch the current host (uses `nixos-rebuild` or `darwin-rebuild`).
- Helpful: `nix flake show` to inspect outputs for hosts and packages.

## Coding Style & Naming Conventions
- Nix: 2-space indent, trailing commas in attrsets, keep options alphabetized where practical.
- Filenames: kebab-case for Nix files (e.g., `home-assistant.nix`).
- Options/attrs: follow upstream naming (camelCase) and avoid unnecessary overrides.
- Shell scripts: POSIX-compatible, `set -euo pipefail`; validate with `shellcheck` locally.

## Testing Guidelines
- Prefer small, composable modules with evaluation-only checks when possible.
- Hooks: keep or add ShellSpec-style tests near `home-manager/claude-code/hooks/spec`.
- Run `make test` before submitting; add fixtures/examples under `fixtures/` when useful.

## Commit & Pull Request Guidelines
- Commits: concise, imperative mood (e.g., `hosts/ultraviolet: fix HASS resources`).
- Scope changes by host/module/package; group related edits together.
- PRs: include summary, affected hosts, rationale, and any `make check` output. Add screenshots for UI/dashboard changes.

## Security & Configuration Tips
- Do not commit secrets. Use example files (e.g., `hosts/ultraviolet/home-assistant-secrets.yaml.example`) and load real values out-of-repo.
- Validate risky changes by building first (example: `make check` then `make update` on the target machine).
