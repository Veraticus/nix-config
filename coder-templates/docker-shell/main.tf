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

variable "entrypoint_shell" {
  description = "Shell binary used to launch the coder agent init script."
  type        = string
  default     = "sh"
}

provider "coder" {}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_provisioner" "me" {}

data "coder_parameter" "workspace_image" {
  description  = "OCI image used for the workspace container."
  display_name = "Workspace Image"
  mutable      = true
  name         = "workspace_image"
  order        = 1
  type         = "string"
  validation {
    regex = "[^\\s]"
    error = "Provide an image reference."
  }
}

locals {
  workspace_home  = "/home/joshsymonds"
  container_name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  git_env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }
  secret_manifest_path = "${local.workspace_home}/.local/state/ee/synced-files"
  agent_env = merge(
    local.git_env,
    {
      PATH                      = "/run/current-system/sw/bin:/usr/bin:/bin"
      CODER_WORKSPACE_NAME      = data.coder_workspace.me.name
      EE_SYNC_MANIFEST_PATH     = local.secret_manifest_path
      WORKSPACE_SECRET_MANIFEST = local.secret_manifest_path
    }
  )
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
  image      = data.coder_parameter.workspace_image.value
  name       = local.container_name
  hostname   = data.coder_workspace.me.name
  entrypoint = ["/usr/bin/env", var.entrypoint_shell, "-lc", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "PATH=/usr/bin:/bin:/run/wrappers/bin:/nix/var/nix/profiles/default/bin"
  ]
  logs = true

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = local.workspace_home
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
  dir  = local.workspace_home

  env = local.agent_env

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

resource "coder_script" "cleanup" {
  agent_id    = coder_agent.main.id
  run_on_stop = true
  script      = <<-EOT
    set -eu

    home="${local.workspace_home}"
    manifest="$${WORKSPACE_SECRET_MANIFEST:-$${EE_SYNC_MANIFEST_PATH:-}}"
    clean_cmd="$${WORKSPACE_SECRET_CLEAN_CMD:-}"

    if [ -n "$manifest" ] && [ -f "$manifest" ]; then
      while IFS= read -r rel || [ -n "$rel" ]; do
        case "$rel" in
          ''|'#'*) continue ;;
        esac

        case "$rel" in
          /*) target="$rel" ;;
          *) target="$home/$rel" ;;
        esac

        case "$target" in
          "$home"|"$home"/*) : ;;
          *) continue ;;
        esac

        if [ -e "$target" ]; then
          rm -rf -- "$target"
        fi
      done < "$manifest"
      rm -f -- "$manifest"
    fi

    if [ -n "$clean_cmd" ]; then
      sh -c "$clean_cmd" || true
    fi
  EOT
}
