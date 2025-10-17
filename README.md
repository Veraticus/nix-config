# Josh Symonds' Nix Configuration

This repository contains my personal Nix configuration for managing my Mac laptop and Linux home servers using a declarative, reproducible approach with Nix flakes.

## Overview

This configuration manages:
- **macOS laptop** (cloudbank) - M-series Mac with nix-darwin
- **Linux servers** - Multiple headless NixOS home servers:
  - ultraviolet, bluedesert, echelon

## Features

- **Unified Configuration**: Single repository managing both macOS and Linux systems
- **Modular Design**: Separated system-level and user-level configurations
- **Consistent Theming**: Catppuccin Mocha theme across all applications
- **Custom Packages**: Currently includes a customized Caddy web server
- **Development Environment**: Neovim, Git, Starship prompt, and modern CLI tools
- **Simplified Architecture**: Streamlined flake structure with minimal abstraction
- **Devspace Development Environment**: Persistent tmux-based remote development sessions
- **Remote Link Opening**: Seamless browser integration for SSH sessions

## Quick Start

### Rebuild System Configuration

On the target machine, use the `update` alias or run directly:

```bash
# macOS
darwin-rebuild switch --flake ".#$(hostname -s)" --option warn-dirty false

# Linux
sudo nixos-rebuild switch --flake ".#$(hostname)" --option warn-dirty false
```

### Update Flake Inputs

```bash
nix flake update
```

### Build Custom Packages

```bash
nix build .#myCaddy  # Custom Caddy web server
```

## Structure

- `flake.nix` - Main entry point and flake configuration
- `hosts/` - System-level configurations for each machine
  - `common.nix` - Shared configuration for Linux servers (NFS mounts)
- `home-manager/` - User-level dotfiles and application configs
  - `common.nix` - Shared configuration across all systems
  - `aarch64-darwin.nix` - macOS-specific user configuration
  - `headless-x86_64-linux.nix` - Linux server user configuration
  - Individual app modules (neovim, zsh, kitty, etc.)
- `pkgs/` - Custom package definitions
- `overlays/` - Nixpkgs modifications
- `secrets/` - Public keys

## Key Applications

### Development
- **Editor**: Neovim with custom configuration
- **Terminal**: Kitty with Catppuccin theme
- **Shell**: Zsh with syntax highlighting and autosuggestions
- **Version Control**: Git
- **AI Assistance**: Claude Code (automatically installed via npm)

### macOS Desktop
- **Window Manager**: Aerospace
- **Package Management**: Homebrew (declaratively managed)

### Server Applications
- **Kubernetes**: k9s for cluster management
- **File Sharing**: NFS mounts to NAS
- **Web Server**: Custom Caddy build

## Notable Changes from Standard Nix Configs

1. **Simplified Flake Structure**: Removed unnecessary helper functions and abstractions
2. **Unified Nixpkgs**: Using nixpkgs-unstable as primary source
3. **Single Overlay**: Consolidated all overlays into one default overlay
4. **Minimal Special Args**: Only passing essential inputs and outputs
5. **Direct Home Manager Integration**: Home Manager configured directly in flake.nix

## Customization

To add a new system:
1. Create a configuration in `hosts/<hostname>/`
2. Add to `flake.nix` under appropriate section (nixosConfigurations or darwinConfigurations)
3. Add hostname to the appropriate list in homeConfigurations

To add a new package:
1. Create package in `pkgs/<name>/default.nix`
2. Add to `pkgs/default.nix`
3. Add to overlay in `overlays/default.nix` if needed globally

## Devspace Development Environment

The Devspace system provides persistent, theme-aware tmux-based development environments on remote servers. Each devspace maintains its own project context, git worktrees, and color theme.

### Key Features
- **Persistent Sessions**: Tmux sessions survive SSH disconnections and system reboots
- **Automatic Restoration**: Sessions and project links are restored after system rebuilds
- **Minimal Resource Usage**: Uninitialized devspaces show only a setup prompt
- **Smart Expansion**: Full environment (claude, nvim, term, logs windows) created on demand
- **Git Worktree Isolation**: Automatic worktree creation when multiple devspaces use the same repo
- **Theme Integration**: Each devspace has its own color scheme from Catppuccin palette
- **State Persistence**: Session state saved automatically on meaningful events

### Available Devspaces
- **Mercury** 🚀 (flamingo) - Quick experiments and prototypes
- **Venus** 🎨 (pink) - Personal creative projects
- **Earth** 🌍 (green) - Primary work project
- **Mars** 🔴 (red) - Secondary work project
- **Jupiter** 🪐 (peach) - Large personal project

### Quick Start

From your Mac:
```bash
# Connect to a devspace (creates minimal session if needed)
earth                          # Connect to Earth devspace

# First time setup - link a project
earth ~/Work/my-project        # Links project and expands to full environment
earth .                        # Link current directory

# Subsequent connections go straight to your dev environment
earth                          # Reconnects to existing session
```

### Command Reference

#### Connection Commands (from Mac)
```bash
earth                          # Connect to devspace (auto-restores if needed)
mars                          # Each devspace has its own command
venus status                  # Show current project and session state
jupiter worktree create feat   # Create a feature branch worktree
```

#### Setup and Management
```bash
# Linking projects
earth /path/to/project         # Link devspace to a project
earth setup ~/Work/project     # Explicit setup command (same as above)
earth .                        # Link to current directory

# Status and info
earth status                   # Show linked project and session state
devspace-status               # Show all devspaces status (alias: ds)

# Git worktrees
earth worktree create feature  # Create a worktree for feature work
earth worktree list           # List all worktrees for this devspace
earth worktree clean          # Remove merged worktrees
```

#### AWS Credential Sync (from Mac)
```bash
devspace-sync-aws             # Sync AWS creds to server (alias: dsa)
devspace-sync-aws earth       # Sync to specific devspace directory
```

### Server-Side Usage

#### Within Tmux Sessions
```bash
# Window navigation
Ctrl-b 1          # Claude window
Ctrl-b 2          # Neovim window
Ctrl-b 3          # Terminal window
Ctrl-b 4          # Logs window

# Quick key shortcuts (when in devspace mode)
Ctrl-b c          # Jump to Claude
Ctrl-b n          # Jump to Neovim
Ctrl-b t          # Jump to Terminal
Ctrl-b l          # Jump to Logs

# Session switching (with Meta/Alt key)
Meta-E            # Switch to Earth session
Meta-M            # Switch to Mars session
Meta-J            # Switch to Jupiter session
# ... etc (uses first letter of devspace name)
```

#### Direct Commands on Server
```bash
# If you SSH directly without using devspace commands
earth             # Attach to Earth session (auto-restores if needed)
mars status      # Check Mars configuration

# Manual session management (rarely needed)
devspace-restore  # Manually restore all sessions from saved state
save_session_state # Manually save current session state
```

### How It Works

1. **Initial State**: On system boot, `devspace-restore` service creates minimal placeholder sessions
2. **First Connection**: Shows welcome screen with setup instructions
3. **Project Linking**: When you link a project, session expands to full 4-window environment
4. **State Persistence**: State saved automatically when:
   - Projects are linked/changed
   - Windows are created/destroyed
   - Clients detach from sessions
   - Every 30 minutes via systemd timer
   - Before system shutdown/rebuild

5. **Restoration**: After reboot/rebuild:
   - Service reads saved state from `~/.local/state/tmux-devspaces/`
   - Recreates sessions with their initialization state
   - Restores project links if directories still exist
   - Falls back to minimal sessions if restoration fails

### Git Worktree Management

When multiple devspaces need the same repository:
```bash
# First devspace gets direct link
earth ~/Work/main-repo       # Links directly

# Second devspace automatically creates worktree
mars ~/Work/main-repo        # Creates worktree at ~/devspaces/mars/worktrees/devspace-mars-TIMESTAMP
```

Worktrees are automatically cleaned up when:
- Branches are merged into main
- You switch to a different project
- You run `earth worktree clean`

### Customization

The devspace theme is defined in `pkgs/devspaces/theme.nix`. To add or modify devspaces:

1. Edit the theme file to add/remove spaces
2. Rebuild your systems
3. New devspaces automatically get:
   - tmux session management
   - Connection shortcuts
   - Color theming
   - State persistence

### Troubleshooting

```bash
# Check systemd service status
systemctl status devspace-restore

# View service logs
journalctl -u devspace-restore -f

# Manually restore sessions
devspace-restore

# Check saved state
cat ~/.local/state/tmux-devspaces/sessions.txt

# Force recreation of a devspace
tmux kill-session -t devspace-earth
earth  # Will auto-restore
```

## Remote Link Opening

When SSH'd into a server, links can be opened on your local Mac browser automatically. This is especially useful for AWS SSO authentication.

### How it Works
1. The server sets `BROWSER=remote-link-open`
2. When applications try to open URLs, they display as clickable links in Kitty
3. Click the link in your terminal to open it in your Mac browser

### Example
```bash
# On the server
aws sso login     # Will display a clickable authentication URL
remote-link-open https://example.com  # Manually open a URL
```

## Testing Changes

See [CLAUDE.md](./CLAUDE.md) for detailed testing procedures. Quick summary:

```bash
# Validate configuration
nix flake check

# Preview changes
darwin-rebuild switch --flake ".#$(hostname -s)" --option warn-dirty false --dry-run

# Build specific components
nix build .#homeConfigurations."joshsymonds@$(hostname -s)".activationPackage
```
