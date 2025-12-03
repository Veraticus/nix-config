# nix-config

Flake-based Nix configuration managing multiple systems.

## Systems

| Host | Platform | Description |
|------|----------|-------------|
| cloudbank | macOS (aarch64-darwin) | Primary dev machine, Aerospace WM |
| ultraviolet | NixOS (x86_64-linux) | Headless server |
| bluedesert | NixOS (x86_64-linux) | Headless server |
| echelon | NixOS (x86_64-linux) | Headless server |

## Essential Commands

```bash
update                    # Rebuild current system (alias)
nix flake check          # Validate flake
nix build .#<package>    # Build a package
```

**IMPORTANT**: Run `update` after any Nix config changes. Nothing takes effect until rebuilt.

**Git gotcha**: Nix flakes only see git-tracked files. Run `git add` before `nix flake check`.

## Directory Structure

```
flake.nix              # Entry point
hosts/                 # System configs (per-machine)
home-manager/          # User configs (apps, dotfiles)
  claude-code/         # Claude Code agents, hooks, settings
pkgs/                  # Custom packages
overlays/              # Nixpkgs modifications
home-assistant/        # HA dashboards and config
```

## Home Assistant

Dashboards use YAML mode - edit files directly, then `update` to deploy.

```bash
hass-cli state list                    # List entities
hass-cli state get <entity_id>         # Get entity state
hass-cli service call <service>        # Call service
```

Token location: `~/.config/home-assistant/token`

## Adding Things

**New system**: Create `hosts/<name>/default.nix`, add to `flake.nix`

**New package**: Create `pkgs/<name>/default.nix`, add to `pkgs/default.nix` and overlay
