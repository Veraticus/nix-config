terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.0"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

variable "docker_socket" {
  description = "(Optional) Docker socket URI."
  type        = string
  default     = ""
}

variable "workspace_image" {
  description = "OCI image used for the workspace container."
  type        = string
  default     = "ghcr.io/veraticus/nix-config/egoengine:latest"
}

variable "entrypoint_shell" {
  description = "Shell binary used to launch the coder agent init script."
  type        = string
  default     = "zsh"
}

variable "op_service_account_token" {
  description = "1Password Service Account token injected into the workspace environment."
  type        = string
  sensitive   = true
  default     = ""
}

provider "coder" {}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_provisioner" "me" {}

locals {
  container_name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  git_env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }
  op_env = var.op_service_account_token == "" ? {} : {
    OP_SERVICE_ACCOUNT_TOKEN = var.op_service_account_token
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  image      = var.workspace_image
  name       = local.container_name
  hostname   = data.coder_workspace.me.name
  entrypoint = ["/usr/bin/env", var.entrypoint_shell, "-lc", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/joshsymonds"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = "/home/joshsymonds"

  env = merge(local.git_env, local.op_env)

  startup_script = <<-EOT
    set -euo pipefail
    mkdir -p ~/.codex
    umask 077

    op read 'op://egoengine/Codex Auth/auth.json' > ~/.codex/auth.json || true
    chmod 600 ~/.codex/auth.json || true
    codex auth me || rm -f ~/.codex/auth.json || true

    if [ -n "$${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -x "$${HOME}/.local/bin/ee" ]; then
      "$${HOME}/.local/bin/ee" sync --quiet || true
    fi
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "home_disk"
    script       = "coder stat disk --path $HOME"
    interval     = 60
    timeout      = 1
  }
}
