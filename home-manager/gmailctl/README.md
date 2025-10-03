# Gmail Filter Management with gmailctl

This module provides a declarative Gmail filter management system using [gmailctl](https://github.com/mbrt/gmailctl).

## Features

- Separate configurations for personal and work Gmail accounts
- Shared filter rules between accounts
- Email pattern analysis scripts
- Version-controlled filter configurations

## Initial Setup (Required!)

Since gmailctl needs to create its own library files during initialization, you must follow these setup steps after installing via nix:

### 1. OAuth Setup (One-time)

Follow the instructions in [setup-oauth.md](./setup-oauth.md) to:
1. Create a Google Cloud Project
2. Enable Gmail API
3. Create OAuth credentials
4. Download `credentials.json`

### 2. Account Setup

For each Gmail account, run these commands:

#### Personal Account (josh@joshsymonds.com)
```bash
# Initialize gmailctl (creates ~/.gmailctl-personal/ with library files)
gcp init

# Copy credentials if not already present
cp ~/Downloads/credentials.json ~/.gmailctl-personal/

# Copy our configuration files
cp ~/nix-config/home-manager/gmailctl/configs/personal.jsonnet ~/.gmailctl-personal/config.jsonnet
cp -r ~/nix-config/home-manager/gmailctl/lib ~/.gmailctl-personal/

# Authenticate (will open browser)
gcp init
```

#### Work Account (josh@crossnokaye.com)
```bash
# Initialize gmailctl (creates ~/.gmailctl-work/ with library files)
gcw init

# Copy credentials if not already present
cp ~/Downloads/credentials.json ~/.gmailctl-work/

# Copy our configuration files
cp ~/nix-config/home-manager/gmailctl/configs/work.jsonnet ~/.gmailctl-work/config.jsonnet
cp -r ~/nix-config/home-manager/gmailctl/lib ~/.gmailctl-work/

# Authenticate (will open browser)
gcw init
```

## Usage

### Aliases

- `gcp` - Manage personal Gmail filters
- `gcw` - Manage work Gmail filters

### Common Commands

```bash
# Preview changes (dry run)
gcp diff
gcw diff

# Apply filters
gcp apply
gcw apply

# Export current Gmail filters
gcp export > personal-current.json
gcw export > work-current.json

# Download current filters as gmailctl config
gcp download > downloaded-personal.jsonnet
gcw download > downloaded-work.jsonnet

# Test configuration
gcp test
gcw test
```

### Email Analysis

After authenticating, analyze your inbox patterns:

```bash
# Switch to account directory first
cd ~/.gmailctl-personal  # or ~/.gmailctl-work

# Run analysis
gmail-analyze
```

This will generate a detailed report of:
- Most common senders and domains
- Subject line patterns
- Mailing lists
- Time distribution
- Filter recommendations

## Configuration Structure

```
gmailctl/
├── configs/
│   ├── personal.jsonnet    # Personal account filters
│   └── work.jsonnet        # Work account filters
├── examples/
│   ├── nuclear-inbox-cleanup.jsonnet  # Archive everything approach
│   └── smart-personal-filters.jsonnet # Research-based best practices
├── lib/
│   └── common-rules.libsonnet  # Shared filter rules
├── scripts/
│   ├── analyze-inbox.py    # Basic inbox analysis
│   └── deep-analyze.py     # Deep pattern analysis
├── WARNINGS-AND-BEST-PRACTICES.md  # Critical warnings & tips
└── setup-oauth.md          # OAuth setup instructions
```

## Example Configurations

- **Nuclear Cleanup**: See `examples/nuclear-inbox-cleanup.jsonnet` for archiving almost everything
- **Smart Filters**: See `examples/smart-personal-filters.jsonnet` for research-based patterns
- **Best Practices**: Read `WARNINGS-AND-BEST-PRACTICES.md` before applying any filters!

## Updating Filters

To update your filters:

1. Edit the appropriate config file in `configs/`
2. Copy to the gmailctl directory:
   ```bash
   cp ~/nix-config/home-manager/gmailctl/configs/personal.jsonnet ~/.gmailctl-personal/config.jsonnet
   ```
3. Preview changes: `gcp diff`
4. Apply if satisfied: `gcp apply`

## Important Notes

- Each account maintains separate OAuth tokens
- The `gmailctl.libsonnet` file is created by gmailctl during init
- Don't edit files directly in `~/.gmailctl-*` directories (except for manual config updates)
- Always use `diff` before `apply` to preview changes

### Spark Compatibility

Spark keys its inbox view and notifications off Gmail's `INBOX` label. The configs in `configs/` deliberately avoid using `archive` or `markRead` actions so messages stay visible to Spark while still getting labeled. If you customize these files, keep Spark happy by sticking to label/importance/star changes only.

## Troubleshooting

### "gmailctl.libsonnet not found" error
Run the initialization again: `gcp init` or `gcw init`

### Authentication errors
1. Ensure `credentials.json` is in the correct directory
2. Try re-authenticating: `gcp init` or `gcw init`
3. Check that Gmail API is enabled in your Google Cloud Project

### Configuration syntax errors
Test your config: `gcp test` or `gcw test`
