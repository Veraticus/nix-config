# Repository Guidelines

## Project Structure & Module Organization
Keep flake entrypoints at the root (`flake.nix`, `flake.lock`). Host-specific NixOS and Darwin configs live under `hosts/<hostname>/` with matching Home Manager profiles in `home-manager/hosts/<hostname>.nix`. Shared modules, overlays, and user applications sit in `modules/`, `overlays/`, and `home-manager/`. Custom packages belong in `pkgs/<name>/default.nix` and are wired up through `pkgs/default.nix`. Use `docs/` and `reference/` for long-form notes, and the root `README.md` for a quick overview before diving in.

## Build, Test, and Development Commands
Run `make lint` to execute `statix`, `deadnix`, and hook linters. `make test` runs ShellSpec fixtures in `home-manager/claude-code/hooks/spec`. `make check` combines linting and tests and should be your default pre-commit gate. When you need to rebuild a machine locally, use `make update` to call `nixos-rebuild` or `darwin-rebuild`. `nix flake show` is handy for inspecting available outputs.

## Coding Style & Naming Conventions
Format Nix with two-space indents, trailing commas in attrsets, and alphabetized options when practical. Stick to kebab-case filenames such as `pkgs/rust-toolchain/default.nix`. Follow upstream option names (often camelCase) instead of inventing aliases. Shell scripts must be POSIX-compliant, begin with `set -euo pipefail`, and pass `shellcheck`.

## Testing Guidelines
Favor evaluation-only tests and focused modules. Expand ShellSpec coverage alongside any hook changes in `home-manager/claude-code/hooks/spec`. Place additional fixtures under `fixtures/` and run `make test` before requesting reviews.

## Commit & Pull Request Guidelines
Write commits in imperative mood (`modules/editor: enable tree-sitter`). Group edits by host or module. Pull requests should summarize the change, call out affected hosts, note `make check` results, and include screenshots for UI-facing tweaks. Link issues when available and describe any follow-up work.

## Security & Configuration Tips
Never commit secrets; use example files like `hosts/ultraviolet/home-assistant-secrets.yaml.example`. For risky changes, validate with `make check`, then `make update` on the target host to ensure the deployment succeeds before merging.
