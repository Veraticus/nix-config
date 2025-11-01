terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.0"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    envbuilder = {
      source = "coder/envbuilder"
    }
  }
}

variable "docker_socket" {
  description = "(Optional) Docker socket URI."
  type        = string
  default     = ""
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

provider "envbuilder" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "repo" {
  description  = "Select a repository to build with Envbuilder."
  display_name = "Repository"
  mutable      = true
  name         = "repo"
  option {
    name        = "vercel/next.js"
    description = "Vercel Next.js example"
    value       = "https://github.com/vercel/next.js"
  }
  option {
    name        = "home-assistant/core"
    description = "Home Assistant core"
    value       = "https://github.com/home-assistant/core"
  }
  option {
    name        = "Custom"
    icon        = "/emojis/1f5c3.png"
    description = "Specify a custom repository URL below."
    value       = "custom"
  }
  order = 1
}

data "coder_parameter" "custom_repo_url" {
  default      = ""
  description  = "Optional custom repository URL."
  display_name = "Repository URL (custom)"
  name         = "custom_repo_url"
  mutable      = true
  order        = 2
}

data "coder_parameter" "fallback_image" {
  default      = "ghcr.io/veraticus/nix-config/egoengine:latest"
  description  = "Base image used when the devcontainer fails to build."
  display_name = "Fallback Image"
  mutable      = true
  name         = "fallback_image"
  order        = 3
}

data "coder_parameter" "devcontainer_builder" {
  description  = <<-EOF
Container image that builds the devcontainer (Envbuilder).
Pin to a specific tag for reproducibility.
See https://github.com/coder/envbuilder/pkgs/container/envbuilder
EOF
  display_name = "Devcontainer Builder"
  mutable      = true
  name         = "devcontainer_builder"
  default      = "ghcr.io/coder/envbuilder:latest"
  order        = 4
}

data "coder_parameter" "cache_repo" {
  default      = ""
  description  = "Optional container registry cache (e.g. ghcr.io/OWNER/envbuilder-cache)."
  display_name = "Cache Registry"
  mutable      = true
  name         = "cache_repo"
  order        = 5
}

data "coder_parameter" "cache_repo_docker_config_path" {
  default      = ""
  description  = "Optional path on the provisioner host to a docker config.json containing registry credentials."
  display_name = "Cache Registry Docker Config Path"
  mutable      = true
  name         = "cache_repo_docker_config_path"
  order        = 6
}

locals {
  container_name             = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  
  devcontainer_builder_image = data.coder_parameter.devcontainer_builder.value
  git_author_name            = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email           = data.coder_workspace_owner.me.email
  repo_url                   = data.coder_parameter.repo.value == "custom" ? data.coder_parameter.custom_repo_url.value : data.coder_parameter.repo.value
  cache_repo                 = data.coder_parameter.cache_repo.value

  envbuilder_env = {
    ENVBUILDER_GIT_URL           = local.repo_url
    ENVBUILDER_CACHE_REPO        = local.cache_repo
    ENVBUILDER_FALLBACK_IMAGE    = data.coder_parameter.fallback_image.value
    ENVBUILDER_DOCKER_CONFIG_BASE64 = try(data.local_sensitive_file.cache_repo_dockerconfigjson[0].content_base64, "")
    ENVBUILDER_PUSH_IMAGE        = local.cache_repo == "" ? "" : "true"
    ENVBUILDER_WORKDIR           = "/home/joshsymonds"
    CODER_AGENT_TOKEN            = coder_agent.main.token
    CODER_AGENT_URL              = replace(data.coder_workspace.me.access_url, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")
    ENVBUILDER_INIT_SCRIPT       = replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")
  }

  entrypoint_shell          = var.entrypoint_shell

  docker_env = [
    for k, v in local.envbuilder_env : "${k}=${v}"
    if v != ""
  ]

  git_env = {
    GIT_AUTHOR_NAME     = local.git_author_name
    GIT_AUTHOR_EMAIL    = local.git_author_email
    GIT_COMMITTER_NAME  = local.git_author_name
    GIT_COMMITTER_EMAIL = local.git_author_email
  }

  op_env = var.op_service_account_token == "" ? {} : {
    OP_SERVICE_ACCOUNT_TOKEN = var.op_service_account_token
  }
}

data "local_sensitive_file" "cache_repo_dockerconfigjson" {
  count    = data.coder_parameter.cache_repo_docker_config_path.value == "" ? 0 : 1
  filename = data.coder_parameter.cache_repo_docker_config_path.value
}

resource "docker_image" "devcontainer_builder_image" {
  name         = local.devcontainer_builder_image
  keep_locally = true
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

resource "envbuilder_cached_image" "cached" {
  count         = local.cache_repo == "" ? 0 : data.coder_workspace.me.start_count
  builder_image = local.devcontainer_builder_image
  git_url       = local.repo_url
  cache_repo    = local.cache_repo
  extra_env     = local.envbuilder_env
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = local.cache_repo == "" ? local.devcontainer_builder_image : envbuilder_cached_image.cached[0].image
  name  = local.container_name
  hostname = data.coder_workspace.me.name
  env = local.cache_repo == "" ? local.docker_env : envbuilder_cached_image.cached[0].env
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

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id

  item {
    key   = "workspace image"
    value = local.cache_repo == "" ? local.devcontainer_builder_image : envbuilder_cached_image.cached[0].image
  }

  item {
    key   = "git url"
    value = local.repo_url
  }

  item {
    key   = "cache repo"
    value = local.cache_repo == "" ? "not configured" : local.cache_repo
  }
}
