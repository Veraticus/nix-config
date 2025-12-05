# Nix Configuration Patterns

Auto-apply when editing `.nix` files or working in this nix-config repo.

## Critical Reminders

**After any change**: Run `update` to rebuild. Nothing takes effect until rebuilt.

**Before `nix flake check`**: Run `git add` on new/modified files. Flakes only see git-tracked files.

## Commands

```bash
update                              # Rebuild current system
nix flake check                     # Validate flake
nix build .#<package>               # Build package
nix eval .#nixosConfigurations.<host>.config.<option>  # Check config value
```

## Package Pattern

```nix
# pkgs/<name>/default.nix
{ lib, stdenv, fetchFromGitHub, ... }:
stdenv.mkDerivation rec {
  pname = "name";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "...";
    repo = "...";
    rev = "v${version}";
    hash = "sha256-AAAA...";  # Use lib.fakeHash first, nix will tell you real hash
  };

  meta = with lib; {
    description = "...";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
```

Then add to `pkgs/default.nix` and `overlays/default.nix`.

## Home Manager Module Pattern

```nix
# home-manager/<app>/default.nix
{ pkgs, lib, ... }: {
  home.packages = [ pkgs.app ];

  # Or use programs.<app> if module exists
  programs.app = {
    enable = true;
    settings = { ... };
  };
}
```

Then import in `home-manager/common.nix` or platform-specific file.

## This Repo's Systems

| Host | Platform | Notes |
|------|----------|-------|
| cloudbank | macOS | Primary dev, Aerospace WM |
| ultraviolet | NixOS | Headless server |
| bluedesert | NixOS | Headless server |
| echelon | NixOS | Headless server |
