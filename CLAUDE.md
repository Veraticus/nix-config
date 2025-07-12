# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a flake-based Nix configuration managing multiple systems:
- NixOS configurations for Linux headless servers (x86_64-linux)
- nix-darwin configuration for macOS (aarch64-darwin)
- Home Manager for user-level configurations
- Custom packages and overlays

## Common Commands

### System Rebuild Commands
- **Linux (NixOS)**: `sudo nixos-rebuild switch --flake ".#$(hostname)"`
- **macOS (darwin)**: `darwin-rebuild switch --flake ".#$(hostname -s)"`
- **Shell alias**: `update` (configured in home-manager)

**IMPORTANT**: After making changes to any Nix configuration files (including hooks), you MUST run `update` to apply the changes to the current system. Changes won't take effect until the system is rebuilt!

### Hook Development Workflow
When working on Claude Code hooks (`home-manager/claude-code/hooks/`):

1. **Test Locally** (no rebuild needed):
   ```bash
   cd home-manager/claude-code/hooks
   make lint    # Run shellcheck on all scripts
   make test    # Run test suites
   make check   # Run both lint and test
   ```

2. **Deploy Changes** (after testing):
   ```bash
   update       # Rebuild system to activate hook changes
   ```

This separation allows rapid development and testing without constant system rebuilds.

### Building Packages
- **Build custom package**: `nix build .#<package>`
  - Available packages: myCaddy
- **Legacy build**: `nix-build -A <package>`

### Flake Commands
- **Update flake inputs**: `nix flake update`
- **Show flake outputs**: `nix flake show`
- **Check flake**: `nix flake check`

## Testing and Validation

### Important: Git and Nix Flakes
**CRITICAL**: Nix flakes only see files that are tracked by git. Before running `nix flake check` or any nix build commands, you MUST:
1. Add all new files to git: `git add <files>`
2. Stage any modifications: `git add -u`
3. Only then run `nix flake check`

This is a common Nix gotcha - untracked files are invisible to flake evaluation!

### Safe Testing Methods
1. **Validate flake structure** (non-destructive):
   ```bash
   nix flake check
   nix flake show
   ```

2. **Dry-run system changes** (preview without applying):
   ```bash
   # macOS
   darwin-rebuild switch --flake ".#$(hostname -s)" --dry-run
   
   # Linux
   sudo nixos-rebuild switch --flake ".#$(hostname)" --dry-run
   ```

3. **Build packages individually** (isolated testing):
   ```bash
   nix build .#myCaddy
   ```

4. **Evaluate configurations** (syntax checking):
   ```bash
   # Evaluate NixOS configurations
   nix eval .#nixosConfigurations.ultraviolet.config.system.build.toplevel
   nix eval .#nixosConfigurations.bluedesert.config.system.build.toplevel
   nix eval .#nixosConfigurations.echelon.config.system.build.toplevel
   
   # Evaluate Darwin configuration
   nix eval .#darwinConfigurations.cloudbank.config.system.build.toplevel
   ```

5. **Test home-manager changes**:
   ```bash
   # Build home configuration without switching
   nix build .#homeConfigurations."joshsymonds@$(hostname -s)".activationPackage
   ```

### Testing Workflow
1. Make configuration changes
2. Run `nix flake check` to validate syntax
3. Use dry-run to preview system changes
4. Build affected packages to ensure they compile
5. Apply changes with rebuild command when satisfied

## Architecture

### Directory Structure
- `flake.nix` - Main entry point defining inputs and outputs
- `hosts/` - System-level configurations
  - Linux servers: ultraviolet, bluedesert, echelon
  - macOS: cloudbank
  - `common.nix` - Shared configuration for Linux servers (NFS mounts)
- `home-manager/` - User configurations
  - `common.nix` - Shared across all systems
  - `aarch64-darwin.nix` - macOS-specific
  - `headless-x86_64-linux.nix` - Linux server-specific
  - Application modules (nvim/, zsh/, kitty/, claude-code/, etc.)
- `pkgs/` - Custom package definitions
- `overlays/` - Nixpkgs modifications
  - Single default overlay combining all modifications
  - Provides `pkgs.stable` for stable packages when needed

### Key Patterns
1. **Modular Configuration**: Each application has its own module in home-manager/
2. **Platform Separation**: Platform-specific settings in separate files
3. **Simplified Overlay System**: Single default overlay for all modifications
4. **Minimal Special Arguments**: Only pass necessary inputs and outputs
5. **Theming**: Consistent Catppuccin Mocha theme across applications

### System Details
- **cloudbank** (macOS laptop): Primary development machine with Aerospace window manager
- **ultraviolet, bluedesert, echelon** (Linux servers): Headless home servers with NFS mounts

### Adding New Systems
1. Create host configuration in `hosts/<hostname>/default.nix`
2. Add to `nixosConfigurations` or `darwinConfigurations` in flake.nix
3. Add hostname to appropriate list in `homeConfigurations` section

### Custom Package Development
1. Add package definition to `pkgs/<package>/default.nix`
2. Include in `pkgs/default.nix`
3. Add to overlay in `overlays/default.nix`