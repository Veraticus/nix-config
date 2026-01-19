# Calendar-MCP Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy calendar-mcp to ultraviolet with CloudFlare Access protection, agenix-managed secrets, and automated backup to NAS.

**Architecture:** HTTP server on port 8001 behind CloudFlare Tunnel, OAuth tokens persisted in /var/lib/calendar-mcp, daily backup to /mnt/backups/calendar-mcp. Uses the NixOS module from calendar-mcp flake.

**Tech Stack:** NixOS, agenix, CloudFlare Access/Tunnel, .NET (calendar-mcp)

---

## Pre-Implementation: OAuth App Setup (Manual)

Before starting, you need to create OAuth applications. This is done in browser, not in code.

### Microsoft Azure AD App

1. Go to https://portal.azure.com → Azure Active Directory → App registrations → New registration
2. Name: "Calendar MCP"
3. Supported account types: "Accounts in any organizational directory and personal Microsoft accounts"
4. Redirect URI: Public client/native, `http://localhost`
5. Click Register
6. Go to API Permissions → Add a permission → Microsoft Graph → Delegated permissions:
   - `Mail.Read`
   - `Mail.Send`
   - `Calendars.ReadWrite`
   - `User.Read`
7. Click "Grant admin consent" if you have admin rights
8. Note the **Application (client) ID** - you'll need this when adding accounts later

### Google Cloud OAuth App

1. Go to https://console.cloud.google.com → APIs & Services → Credentials
2. Create project if needed
3. Click "Create Credentials" → OAuth 2.0 Client IDs → Desktop app
4. Go to OAuth consent screen → Add scopes:
   - `https://www.googleapis.com/auth/gmail.readonly`
   - `https://www.googleapis.com/auth/gmail.send`
   - `https://www.googleapis.com/auth/calendar.readonly`
   - `https://www.googleapis.com/auth/calendar.events`
5. Enable APIs: Gmail API, Google Calendar API
6. Note the **Client ID** and **Client Secret** - you'll encrypt the secret with agenix

### CloudFlare Access Application

1. Go to https://one.dash.cloudflare.com → Access → Applications → Add an application
2. Self-hosted
3. Application name: "Calendar MCP"
4. Session duration: 24 hours (or your preference)
5. Application domain: `calendar-mcp.husbuddies.gay`
6. Add a policy to allow your users
7. Go to Settings → OIDC → Note:
   - **Client ID**
   - **Client Secret**
   - **OIDC Config URL**: `https://husbuddies.cloudflareaccess.com/cdn-cgi/access/sso/oidc/<app-id>/.well-known/openid-configuration`

---

## Task 1: Add calendar-mcp Input to Flake

**Files:**
- Modify: `flake.nix:46-49` (after redlib-mcp input)

**Step 1: Add the input**

Add after line 49 (after `redlib-mcp.url`):

```nix
    # Calendar MCP - unified email/calendar for Claude
    calendar-mcp.url = "github:Veraticus/calendar-mcp";
```

**Step 2: Verify flake parses**

Run: `nix flake check --no-build 2>&1 | head -20`

Expected: No syntax errors. May show warnings about missing lock entry (that's OK).

**Step 3: Update flake.lock**

Run: `nix flake update calendar-mcp`

Expected: Output showing calendar-mcp added to lock file.

**Step 4: Verify input is available**

Run: `nix flake show --json | jq '.nixosModules'`

Expected: Should include calendar-mcp's module (may need the full flake path).

**Step 5: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat: add calendar-mcp flake input"
```

---

## Task 2: Add Secret Declarations

**Files:**
- Modify: `secrets/secrets.nix:16` (after mcp-jwt-secret line)

**Step 1: Add secret declarations**

Add after line 16 (after `mcp-jwt-secret.age` line):

```nix
  "secrets/hosts/ultraviolet/calendar-mcp-cf-client-id.age".publicKeys = keys.ultraviolet;
  "secrets/hosts/ultraviolet/calendar-mcp-cf-client-secret.age".publicKeys = keys.ultraviolet;
  "secrets/hosts/ultraviolet/calendar-mcp-google-secret.age".publicKeys = keys.ultraviolet;
```

**Step 2: Verify syntax**

Run: `nix-instantiate --eval secrets/secrets.nix --json | jq 'keys'`

Expected: List including the three new secret paths.

**Step 3: Commit**

```bash
git add secrets/secrets.nix
git commit -m "feat: declare calendar-mcp secrets in agenix"
```

---

## Task 3: Create Encrypted Secrets

**Files:**
- Create: `secrets/hosts/ultraviolet/calendar-mcp-cf-client-id.age`
- Create: `secrets/hosts/ultraviolet/calendar-mcp-cf-client-secret.age`
- Create: `secrets/hosts/ultraviolet/calendar-mcp-google-secret.age`

**Step 1: Create CloudFlare client ID secret**

Run (replace with your actual value):
```bash
echo -n "YOUR_CF_CLIENT_ID_HERE" | agenix -e secrets/hosts/ultraviolet/calendar-mcp-cf-client-id.age
```

Expected: File created, encrypted with age.

**Step 2: Create CloudFlare client secret**

Run (replace with your actual value):
```bash
echo -n "YOUR_CF_CLIENT_SECRET_HERE" | agenix -e secrets/hosts/ultraviolet/calendar-mcp-cf-client-secret.age
```

Expected: File created, encrypted with age.

**Step 3: Create Google client secret**

Run (replace with your actual value):
```bash
echo -n "YOUR_GOOGLE_CLIENT_SECRET_HERE" | agenix -e secrets/hosts/ultraviolet/calendar-mcp-google-secret.age
```

Expected: File created, encrypted with age.

**Step 4: Verify secrets can be decrypted**

Run: `agenix -d secrets/hosts/ultraviolet/calendar-mcp-cf-client-id.age`

Expected: Your client ID printed to stdout.

**Step 5: Commit**

```bash
git add secrets/hosts/ultraviolet/calendar-mcp-*.age
git commit -m "feat: add encrypted calendar-mcp secrets"
```

---

## Task 4: Create Service Configuration

**Files:**
- Create: `hosts/ultraviolet/services/calendar-mcp.nix`

**Step 1: Create the service file**

Create file `hosts/ultraviolet/services/calendar-mcp.nix`:

```nix
{
  pkgs,
  config,
  inputs,
  ...
}: let
  backupScript = pkgs.writeShellScript "backup-calendar-mcp" ''
    set -euo pipefail

    SOURCE_DIR="/var/lib/calendar-mcp"
    BACKUP_BASE="/mnt/backups/calendar-mcp"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_PATH="$BACKUP_BASE/$TIMESTAMP"

    # Ensure backup mount is available
    if ! mountpoint -q /mnt/backups; then
      echo "Error: /mnt/backups is not mounted"
      exit 1
    fi

    mkdir -p "$BACKUP_BASE"

    echo "Backing up Calendar MCP data..."
    echo "Source: $SOURCE_DIR"
    echo "Destination: $BACKUP_PATH"

    # Backup the data directory
    ${pkgs.rsync}/bin/rsync -rlptDv --delete \
      "$SOURCE_DIR/" "$BACKUP_PATH/"

    # Update latest symlink
    ln -sfn "$BACKUP_PATH" "$BACKUP_BASE/latest"

    # Clean up old backups (keep 14 days)
    ${pkgs.findutils}/bin/find "$BACKUP_BASE" -maxdepth 1 -type d -name "20*" -mtime +14 -exec rm -rf {} \; 2>/dev/null || true

    BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
    echo "Backup completed: $TIMESTAMP (Size: $BACKUP_SIZE)"
    logger -t calendar-mcp-backup "Backup completed: $TIMESTAMP (Size: $BACKUP_SIZE)"
  '';
in {
  imports = [
    inputs.calendar-mcp.nixosModules.default
  ];

  # Declare the secrets
  age.secrets."calendar-mcp-cf-client-id" = {
    file = ../../../secrets/hosts/ultraviolet/calendar-mcp-cf-client-id.age;
    owner = "calendar-mcp";
    group = "calendar-mcp";
    mode = "0400";
  };

  age.secrets."calendar-mcp-cf-client-secret" = {
    file = ../../../secrets/hosts/ultraviolet/calendar-mcp-cf-client-secret.age;
    owner = "calendar-mcp";
    group = "calendar-mcp";
    mode = "0400";
  };

  age.secrets."calendar-mcp-google-secret" = {
    file = ../../../secrets/hosts/ultraviolet/calendar-mcp-google-secret.age;
    owner = "calendar-mcp";
    group = "calendar-mcp";
    mode = "0400";
  };

  # Use the calendar-mcp NixOS module
  services.calendar-mcp = {
    enable = true;
    transport = "http";
    host = "127.0.0.1";
    port = 8001;
    accessClientIdFile = config.age.secrets."calendar-mcp-cf-client-id".path;
    accessClientSecretFile = config.age.secrets."calendar-mcp-cf-client-secret".path;
    accessConfigUrl = "https://husbuddies.cloudflareaccess.com/cdn-cgi/access/sso/oidc/REPLACE_WITH_APP_ID/.well-known/openid-configuration";
  };

  # Make CLI available system-wide for account management
  environment.systemPackages = [
    inputs.calendar-mcp.packages.${pkgs.system}.cli
  ];

  # Backup service
  systemd.services.calendar-mcp-backup = {
    description = "Calendar MCP backup";
    after = ["mnt-backups.mount"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backupScript}";
    };
  };

  # Daily backup timer at 3:15 AM (after Home Assistant backup at 3:00)
  systemd.timers.calendar-mcp-backup = {
    description = "Daily Calendar MCP backup timer";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:15:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };
}
```

**Step 2: Verify file syntax**

Run: `nix-instantiate --parse hosts/ultraviolet/services/calendar-mcp.nix`

Expected: Parsed AST output (no errors).

**Step 3: Commit**

```bash
git add hosts/ultraviolet/services/calendar-mcp.nix
git commit -m "feat: add calendar-mcp service configuration"
```

---

## Task 5: Import Service in Ultraviolet

**Files:**
- Modify: `hosts/ultraviolet/default.nix:40` (after redlib-mcp import)

**Step 1: Add the import**

Add after line 40 (`./services/redlib-mcp.nix`):

```nix
      ./services/calendar-mcp.nix
```

**Step 2: Verify configuration builds**

Run: `nix build .#nixosConfigurations.ultraviolet.config.system.build.toplevel --dry-run 2>&1 | tail -10`

Expected: Shows build plan without errors. May take time to evaluate.

**Step 3: Commit**

```bash
git add hosts/ultraviolet/default.nix
git commit -m "feat: enable calendar-mcp on ultraviolet"
```

---

## Task 6: Update CloudFlare Access Config URL

**Files:**
- Modify: `hosts/ultraviolet/services/calendar-mcp.nix:74`

**Step 1: Get your CloudFlare Access app ID**

From CloudFlare Zero Trust dashboard → Access → Applications → Calendar MCP → Settings → Copy the OIDC config URL.

It will look like: `https://husbuddies.cloudflareaccess.com/cdn-cgi/access/sso/oidc/abc123def456/.well-known/openid-configuration`

**Step 2: Update the config URL**

Replace `REPLACE_WITH_APP_ID` in line 74 with your actual app ID.

**Step 3: Commit**

```bash
git add hosts/ultraviolet/services/calendar-mcp.nix
git commit -m "feat: configure calendar-mcp CloudFlare Access URL"
```

---

## Task 7: Deploy to Ultraviolet

**Step 1: Push branch to remote (optional, for backup)**

Run: `git push -u origin feature/calendar-mcp-integration`

**Step 2: Build and deploy**

Run: `nixos-rebuild switch --flake .#ultraviolet --target-host ultraviolet --use-remote-sudo`

Expected: Build completes, services restart. May take several minutes for first build.

**Step 3: Verify service is running**

Run (on ultraviolet): `systemctl status calendar-mcp`

Expected: Active (running).

**Step 4: Verify health endpoint**

Run (on ultraviolet): `curl http://localhost:8001/health`

Expected: Health check response (200 OK or similar).

**Step 5: Verify backup timer**

Run (on ultraviolet): `systemctl list-timers | grep calendar-mcp`

Expected: Shows calendar-mcp-backup.timer with next run time.

---

## Task 8: Add CloudFlare Tunnel Route

**Step 1: Open CloudFlare Tunnel dashboard**

Go to: https://one.dash.cloudflare.com → Networks → Tunnels → ultraviolet tunnel → Public Hostname

**Step 2: Add new route**

- Subdomain: `calendar-mcp`
- Domain: `husbuddies.gay`
- Service Type: HTTP
- URL: `localhost:8001`

**Step 3: Verify external access**

Visit: `https://calendar-mcp.husbuddies.gay`

Expected: Redirects to CloudFlare Access login. After authenticating, shows MCP server response or health page.

---

## Task 9: Add Calendar Accounts

**Step 1: SSH into ultraviolet**

Run: `ssh ultraviolet`

**Step 2: Add Microsoft 365 account**

Run: `calendar-mcp-cli add-m365-account --device-code`

Follow the prompts:
- Enter account ID (e.g., `work-m365`)
- Enter display name (e.g., `Work`)
- Enter client ID (from Azure AD app)
- Enter tenant ID (or `common` for multi-tenant)

The CLI will display a device code and URL. Open the URL in a browser, enter the code, and authorize.

Expected: "Account added successfully"

**Step 3: Add Google account**

Run: `calendar-mcp-cli add-google-account --device-code`

Follow the prompts:
- Enter account ID (e.g., `personal-gmail`)
- Enter display name (e.g., `Personal`)
- Enter client ID (from Google Cloud)
- Enter client secret (from Google Cloud)
- Enter user email

The CLI will display a device code and URL. Open the URL, enter the code, and authorize.

Expected: "Account added successfully"

**Step 4: Verify accounts**

Run: `calendar-mcp-cli list-accounts`

Expected: Shows both accounts with status "authenticated".

**Step 5: Test accounts**

Run: `calendar-mcp-cli test-account work-m365`
Run: `calendar-mcp-cli test-account personal-gmail`

Expected: Both show successful connection and can fetch calendar/email.

---

## Task 10: Test End-to-End

**Step 1: Restart service to pick up new accounts**

Run (on ultraviolet): `sudo systemctl restart calendar-mcp`

**Step 2: Test via Claude Desktop or curl**

The MCP server should now be accessible at `https://calendar-mcp.husbuddies.gay` with CloudFlare Access protection.

**Step 3: Run manual backup test**

Run (on ultraviolet): `sudo systemctl start calendar-mcp-backup`

Then: `ls -la /mnt/backups/calendar-mcp/`

Expected: Backup directory created with timestamp.

**Step 4: Verify backup contents**

Run: `ls -la /mnt/backups/calendar-mcp/latest/`

Expected: Contains `.local/share/CalendarMcp/` with config and token files.

---

## Task 11: Merge and Cleanup

**Step 1: Verify all commits**

Run: `git log --oneline main..HEAD`

Expected: 6-7 commits for the integration.

**Step 2: Merge to main**

Run:
```bash
git checkout main
git merge feature/calendar-mcp-integration
git push
```

**Step 3: Delete feature branch**

Run: `git branch -d feature/calendar-mcp-integration`

---

## Troubleshooting

### Service won't start

Check logs: `journalctl -u calendar-mcp -f`

Common issues:
- Missing secrets: Verify agenix secrets exist and have correct permissions
- Port conflict: Verify nothing else is on port 8001
- Missing data dir: Service should create it, but verify `/var/lib/calendar-mcp` exists

### CloudFlare Access not working

- Verify the OIDC config URL is correct
- Check that the CloudFlare Access app has the correct domain
- Verify the tunnel route points to `localhost:8001`

### Accounts not persisting

Token files should be in `/var/lib/calendar-mcp/.local/share/CalendarMcp/`:
- `msal_cache_*.bin` for Microsoft
- `google/*/` for Google

If missing after restart, check:
- Service user has write access to data dir
- `HOME` environment variable is set correctly in systemd service

### Backup fails

- Verify NFS mount: `mountpoint -q /mnt/backups`
- Check backup script manually: `sudo /nix/store/.../backup-calendar-mcp`
- View backup logs: `journalctl -u calendar-mcp-backup`
