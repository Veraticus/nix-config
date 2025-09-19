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

### Home Assistant API Access
Use a long-lived access token stored in your user config:
- Token location: `~/.config/home-assistant/token` (respects `XDG_CONFIG_HOME`)
- Usage: Use this token in the Authorization header when making API calls to Home Assistant
- Example: `curl -H "Authorization: Bearer $(cat ~/.config/home-assistant/token)" http://localhost:8123/api/states`
- Purpose: Programmatic access to Home Assistant (checking entity states, device info, etc.)

### Claude Code Hooks Overview

This project includes smart hooks that automatically run lint and test commands when files are edited:

- **smart-lint.sh** - Finds and runs project lint commands (`make lint`, `npm run lint`, etc.)
- **smart-test.sh** - Finds and runs project test commands (`make test`, `npm run test`, etc.)

Key features:
- **Automatic discovery** - Walks up directory tree to find project commands
- **PID-based locking** - Prevents concurrent runs in same workspace
- **Configurable cooldown** - Default 2 seconds between runs
- **Smart output** - Shows success messages or blocks on failures

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

## Claude Code Hook Development Guidelines

### Exit Code Behavior

Claude Code hooks use specific exit codes:

- **Exit 0**: Continue operation silently (no user feedback)
- **Exit 1**: General error (missing dependencies, configuration issues)
- **Exit 2**: Display message to user (for BOTH errors AND success!)

**IMPORTANT**: Exit code 2 is used for ANY message that should be shown to the user:
- Error messages: `exit 2` with red error text
- Success messages: `exit 2` with green success text (e.g., "✅ All style checks passed")
- This allows hooks to provide positive feedback, not just error reporting

#### Example Patterns

```bash
# Success with feedback (common pattern)
echo -e "${GREEN}✅ All tests passed${NC}" >&2
exit 2  # Show success message to user

# Error with feedback
echo -e "${RED}❌ Linting failed${NC}" >&2
exit 2  # Block operation and show error

# Silent success (less common)
exit 0  # Continue without feedback
```

When writing tests, remember:
- `The status should equal 2` for BOTH success and error cases that show messages
- Check stderr content to verify success vs error
- `The status should equal 0` only for truly silent operations

### ShellSpec Test Syntax

#### ⚠️ NEVER USE INLINE BEFOREEACH/AFTEREACH BLOCKS ⚠️

ShellSpec does **NOT** support inline code blocks for `BeforeEach`/`AfterEach`. This invalid syntax will cause "Unexpected 'End'" errors:

```bash
# ❌ INVALID - THIS DOES NOT WORK
BeforeEach
    TEMP_DIR=$(create_test_dir)
    cd "$TEMP_DIR" || return
End

# ❌ ALSO INVALID - MIXING FUNCTION NAME WITH INLINE CODE
BeforeEach 'setup_test'
    TEMP_DIR=$(create_test_dir)
    cd "$TEMP_DIR" || return
End
```

#### ✅ CORRECT: Use Function Definitions

ShellSpec **ONLY** supports function references for hooks:

```bash
# ✅ CORRECT - Define function first, then reference it
setup_test() {
    TEMP_DIR=$(create_test_dir)
    cd "$TEMP_DIR" || return
    export CLAUDE_HOOKS_DEBUG=0
}

cleanup_test() {
    cd "$SPEC_DIR" || return
    rm -rf "$TEMP_DIR"
}

BeforeEach 'setup_test'
AfterEach 'cleanup_test'
```

#### Other Critical ShellSpec Rules

1. **No `Include spec_helper`** - ShellSpec automatically loads spec_helper.sh via `--require spec_helper` in .shellspec
2. **One evaluation per test** - Only one `When call` statement allowed per `It` block
3. **Array testing** - Cannot use `The length of ARRAY_NAME`. Test array elements individually.
4. **Pattern matching** - Use `[[]` to match literal `[` in patterns

#### Common Pitfalls to Avoid

- **DO NOT** try to create inline BeforeEach/AfterEach blocks - they are not supported
- **DO NOT** put `Include spec_helper` inside Describe blocks
- **DO NOT** use multiple `When call` statements in a single test
- **DO NOT** ignore the `--fail-fast` issue - it can mask real test failures with cryptic errors

#### Debugging Test Failures

When tests fail unexpectedly:

1. **Use ShellSpec's `Dump` helper** to see actual output:
   ```bash
   When run some_command
   Dump  # Shows stdout, stderr, and status
   The status should equal 0
   ```

2. **Use the debug formatter** for detailed output:
   ```bash
   shellspec spec/test_spec.sh -f debug
   ```

3. **Add debug logging to hooks**:
   ```bash
   log_debug "Current state: $VAR"
   ```
   Then use the `run_hook_with_json_debug` helper in tests.

**Note**: If a test suddenly passes after adding `Dump`, this may indicate timing issues or ShellSpec state problems.

### Hook Implementation Guidelines

#### JSON Protocol

All hooks must properly implement the Claude Code JSON protocol:

1. Read JSON from stdin
2. Parse event type, tool name, and parameters
3. Process only PostToolUse events for relevant tools
4. Use proper exit codes:
   - 0: Continue operation
   - 1: Error (missing dependencies, etc.)
   - 2: Block operation (linting/test failures)

#### Hook Directory Structure

```
home-manager/claude-code/hooks/
├── common-helpers.sh      # Shared utilities
├── smart-lint.sh         # Main linting orchestrator
├── smart-test.sh         # Main testing orchestrator
├── lint-*.sh            # Language-specific linters
├── test-*.sh            # Language-specific test runners
├── spec/                # ShellSpec tests
│   ├── spec_helper.sh   # Test utilities (auto-loaded)
│   └── *_spec.sh        # Test files
└── README.md            # User documentation
```

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
