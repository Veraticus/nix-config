---
name: managing-n8n
description: Manages n8n workflow automation on ultraviolet. Use when creating workflows, managing backups, configuring credentials, or service operations.
---

# n8n Workflow Automation

## Workflow Authoring

**Claude creates workflows as JSON files in `n8n/workflows/`**. They sync to n8n on rebuild.

```
User describes intent → Claude creates JSON → `update` syncs to n8n → User tests in UI
```

If user modifies in UI and wants to reconcile:
```bash
n8n-export <workflow-id>              # Export specific workflow
n8n-export all                        # Export all workflows
# Then copy from /tmp/n8n-export to nix-config/n8n/workflows/
```

## Workflow JSON Structure

```json
{
  "id": "unique-workflow-id",
  "name": "Workflow Name",
  "active": false,
  "nodes": [
    {
      "id": "node-uuid",
      "name": "Node Name",
      "type": "n8n-nodes-base.webhook",
      "position": [250, 300],
      "parameters": {}
    }
  ],
  "connections": {
    "Node Name": {
      "main": [[{"node": "Next Node", "type": "main", "index": 0}]]
    }
  }
}
```

## Common Node Types

| Node | Type String | Use |
|------|-------------|-----|
| Webhook | `n8n-nodes-base.webhook` | HTTP trigger |
| Schedule | `n8n-nodes-base.scheduleTrigger` | Cron trigger |
| HTTP Request | `n8n-nodes-base.httpRequest` | API calls |
| Code | `n8n-nodes-base.code` | JavaScript |
| AI Agent | `@n8n/n8n-nodes-langchain.agent` | LLM agent |
| Anthropic Chat | `@n8n/n8n-nodes-langchain.lmChatAnthropic` | Claude model |

## Deployment

- **URL**: https://n8n.husbuddies.gay
- **Host**: ultraviolet (NixOS)
- **Workflows**: `n8n/workflows/*.json` (git-tracked)
- **Config**: `hosts/ultraviolet/services/n8n.nix`

## Service Commands

```bash
systemctl status n8n.service           # Check status
journalctl -u n8n.service -f           # View logs
sudo systemctl restart n8n.service     # Restart (reimports workflows)
```

## Backup & Restore

```bash
n8n-restore list                       # List backups
n8n-restore latest                     # Restore from latest
```

## Anthropic/AI Setup

**Credentials MUST be configured via n8n UI** - env vars don't work.

1. Open https://n8n.husbuddies.gay
2. Settings → Credentials → Add Credential → Anthropic
3. Enter API key and save

## Common Mistakes

| Wrong | Right |
|-------|-------|
| Setting `ANTHROPIC_API_KEY` env var | Configure in n8n UI → Credentials |
| Editing workflows only in UI | Create JSON in `n8n/workflows/`, run `update` |
| Expecting UI changes to persist | Export with `n8n-export` and commit to git |
| `docker exec n8n ...` | Direct systemctl (not containerized) |

## Directory Structure

```
nix-config/
└── n8n/workflows/          # Git-tracked workflow JSON files
    └── *.json              # Claude creates these

/var/lib/n8n/               # n8n database (synced from git on rebuild)
/mnt/backups/n8n/           # Daily backups to NAS
```
