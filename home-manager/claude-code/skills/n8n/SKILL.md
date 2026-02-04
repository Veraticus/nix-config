---
name: managing-n8n
description: Manages n8n workflow automation on ultraviolet. Use when working with n8n workflows, backups, credentials, or service operations.
---

# n8n Workflow Automation

## Deployment

- **URL**: https://n8n.husbuddies.gay
- **Host**: ultraviolet (NixOS)
- **Port**: 5678 (localhost)
- **Auth**: Cloudflare Access (n8n auth bypassed)
- **Config**: `hosts/ultraviolet/services/n8n.nix`

## Service Commands

```bash
systemctl status n8n.service      # Check status
journalctl -u n8n.service -f      # View logs
sudo systemctl restart n8n.service # Restart
curl -s http://localhost:5678/healthz # Test connectivity
```

## Backup & Restore

Backups run daily at 3:30 AM to `/mnt/backups/n8n` (NAS).

```bash
n8n-restore list                      # List available backups
n8n-restore latest                    # Restore from latest
n8n-restore backup-20260204-033000    # Restore specific backup
```

## Anthropic/AI Setup

**Anthropic credentials MUST be configured via n8n's credential UI.**

Environment variables like `ANTHROPIC_API_KEY` or `N8N_AI_ANTHROPIC_API_KEY` do NOT work - n8n does not read Anthropic keys from environment variables.

Setup steps:
1. Open https://n8n.husbuddies.gay
2. Settings → Credentials → Add Credential
3. Search "Anthropic" → Enter API key
4. Save and use in AI Agent nodes

## Common Mistakes

| Wrong | Right |
|-------|-------|
| `n8n export:backup --list` | `n8n-restore list` |
| Setting `ANTHROPIC_API_KEY` env var | Configure in n8n UI → Credentials |
| `docker exec n8n ...` | Direct systemctl (not containerized) |

## Environment Variables

These are set in NixOS config (NOT for API keys):

| Variable | Value |
|----------|-------|
| `N8N_HOST` | n8n.husbuddies.gay |
| `N8N_PROTOCOL` | https |
| `WEBHOOK_URL` | https://n8n.husbuddies.gay/ |
| `N8N_AUTH_EXCLUDE_ENDPOINTS` | * |
| `N8N_TRUST_PROXY` | true |

## Workflow Patterns

### Webhook Trigger
Webhooks accessible at `https://n8n.husbuddies.gay/webhook/<path>`

### AI Agent with Anthropic
Use `@n8n/n8n-nodes-langchain.agent` node with Anthropic credential configured via UI.

## Directory Structure

```
/var/lib/n8n/           # Data directory (DynamicUser)
├── .n8n/
│   ├── database.sqlite # Workflows, credentials, executions
│   └── config
/mnt/backups/n8n/       # Backup location (NAS)
├── backup-YYYYMMDD-HHMMSS/
└── latest -> backup-*/
```

## Updating n8n

Version pinned in `overlays/default.nix`. To update:
1. Find new version at https://github.com/n8n-io/n8n/releases
2. Update version and hashes in overlay
3. Run `update` to rebuild
