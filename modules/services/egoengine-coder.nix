{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    mkOption
    mkOverride
    optional
    optionalAttrs
    types
    ;

  cfg = config.services.egoengine.coder;

  containerPrefix =
    if cfg.dockerSocketPath != null
    then "docker"
    else "podman";
  containerServiceName = "${containerPrefix}-${cfg.containerName}";
  containerUnit = "${containerServiceName}.service";
in {
  options.services.egoengine.coder = {
    enable = mkEnableOption "self-hosted Coder service";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/coder/coder:v2.14.1";
      description = "Container image for the Coder control plane.";
    };

    containerName = mkOption {
      type = types.str;
      default = "coder";
      description = "Name of the OCI container running Coder.";
    };

    dockerSocketPath = mkOption {
      type = types.nullOr types.str;
      default = "/var/run/docker.sock";
      description = ''Path to a Docker-compatible socket exposed to the Coder container. Set to null to manage provisioning connectivity externally.'';
    };

    port = mkOption {
      type = types.port;
      default = 7080;
      description = "Host port to expose the Coder HTTP service on.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address to bind the Coder HTTP service to.";
    };

    internalUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Internal URL for CLI interactions (defaults to http://127.0.0.1:<port>).";
    };

    accessUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Public URL for Coder (CODER_ACCESS_URL).";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/coder";
      description = "Persistent data directory shared with the Coder container.";
    };

    environmentFile = mkOption {
      type = types.path;
      default = "/etc/coder/coder.env";
      description = "Environment file sourced by the Coder container.";
    };

    databaseEnvFile = mkOption {
      type = types.path;
      default = "/etc/coder/db.env";
      description = "Environment file storing the PostgreSQL password.";
    };

    databaseName = mkOption {
      type = types.str;
      default = "coder";
      description = "Name of the PostgreSQL database used by Coder.";
    };

    databaseUser = mkOption {
      type = types.str;
      default = "coder";
      description = "Name of the PostgreSQL user used by Coder.";
    };

    postgresqlPackage = mkOption {
      type = types.package;
      default = pkgs.postgresql_15;
      defaultText = lib.literalExpression "pkgs.postgresql_15";
      description = "PostgreSQL package used for the database service.";
    };

    autoRegisterTemplates = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically register the bundled templates once Coder is ready.";
    };

    templatePush = mkOption {
      type = types.submodule {
        options = {
          envbuilderName = mkOption {
            type = types.str;
            default = "docker-envbuilder";
            description = "Name for the Envbuilder template.";
          };
          envbuilderPath = mkOption {
            type = types.path;
            default = ../../coder-templates/docker-envbuilder;
            description = "Path to the Envbuilder template definition.";
          };
          shellName = mkOption {
            type = types.str;
            default = "docker-shell";
            description = "Name for the shell-only template.";
          };
          shellPath = mkOption {
            type = types.path;
            default = ../../coder-templates/docker-shell;
            description = "Path to the shell template definition.";
          };
        };
      };
      default = {};
      description = "Template registration parameters.";
    };
  };

  config = mkIf cfg.enable (let
    dbSecretPath = config.age.secrets."coder-db-password".path;
    coderSecretPath = config.age.secrets."coder-env".path;
    internalUrl =
      if cfg.internalUrl != null
      then cfg.internalUrl
      else "http://127.0.0.1:${toString cfg.port}";
    dockerGroupGid = lib.attrByPath ["users" "groups" "docker" "gid"] null config;
    setPasswordScript = pkgs.writeShellScript "coder-postgres-password" ''
            set -euo pipefail

            if [ -f ${cfg.databaseEnvFile} ]; then
              # shellcheck disable=SC1090
              source ${cfg.databaseEnvFile}
            elif [ -f ${dbSecretPath} ]; then
              # shellcheck disable=SC1090
              source ${dbSecretPath}
            else
              echo "Coder database env file ${cfg.databaseEnvFile} is missing" >&2
              exit 1
            fi

            if [ -z "''${CODER_DB_PASSWORD:-}" ]; then
              echo "CODER_DB_PASSWORD is empty; refusing to continue" >&2
              exit 1
            fi

            delimiter="pw"
            while [[ "$CODER_DB_PASSWORD" == *"$delimiter"* ]]; do
              delimiter="''${delimiter}_"
            done

            dollar_delim=$(${pkgs.coreutils}/bin/printf '$%s$' "$delimiter")
            do_tag="coder_pw"
            do_delim=$(${pkgs.coreutils}/bin/printf '$%s$' "$do_tag")

      ${cfg.postgresqlPackage}/bin/psql \
              --dbname=postgres \
              --tuples-only \
              --set=ON_ERROR_STOP=1 <<SQL
      DO $do_delim
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${cfg.databaseUser}') THEN
          EXECUTE 'CREATE ROLE ${cfg.databaseUser} LOGIN';
        END IF;
      END;
      $do_delim;
      ALTER ROLE ${cfg.databaseUser} WITH LOGIN PASSWORD $dollar_delim$CODER_DB_PASSWORD$dollar_delim;
      GRANT ALL PRIVILEGES ON DATABASE ${cfg.databaseName} TO ${cfg.databaseUser};
      SQL
    '';

    templateRegistrationScript = pkgs.writeShellScript "coder-register-templates" ''
      set -euo pipefail

      if [ ! -f ${cfg.environmentFile} ]; then
        echo "Coder env file ${cfg.environmentFile} not found; skipping template registration" >&2
        exit 0
      fi

      # shellcheck disable=SC1090
      source ${cfg.environmentFile}

      CODER_URL="''${CODER_INTERNAL_URL:-${internalUrl}}"
      if [ -z "''${CODER_URL}" ]; then
        CODER_URL="${
        if cfg.accessUrl != null
        then cfg.accessUrl
        else ""
      }"
      fi
      if [ -z "''${CODER_URL}" ]; then
        CODER_URL="''${CODER_ACCESS_URL:-}"
      fi
      if [ -z "''${CODER_URL}" ]; then
        echo "Coder URL not configured; cannot register templates" >&2
        exit 1
      fi

      if command -v coder >/dev/null 2>&1; then
        if [ -n "''${CODER_ADMIN_TOKEN:-}" ]; then
          export CODER_SESSION_TOKEN="''${CODER_ADMIN_TOKEN}"
        fi
        export CODER_URL="''${CODER_URL}"

        TEMPLATE_FLAGS=()
        if [ -n "''${CODER_PROVISIONER_TAGS:-}" ]; then
          IFS=',' read -ra TAGS <<<"''${CODER_PROVISIONER_TAGS}"
          for tag in "''${TAGS[@]}"; do
            TEMPLATE_FLAGS+=(--provisioner-tag "$tag")
          done
        fi

        coder templates push \
          --name ${cfg.templatePush.envbuilderName} \
          "${cfg.templatePush.envbuilderPath}" \
          --yes \
          "''${TEMPLATE_FLAGS[@]}"

        coder templates push \
          --name ${cfg.templatePush.shellName} \
          "${cfg.templatePush.shellPath}" \
          --yes \
          "''${TEMPLATE_FLAGS[@]}"
      else
        echo "coder CLI is not available; skipping template registration" >&2
      fi
    '';
  in
    mkMerge [
      {
        assertions = [
          {
            assertion = cfg.accessUrl != null;
            message = "services.egoengine.coder.accessUrl must be set when enabling the Coder service.";
          }
        ];

        age.secrets."coder-db-password" = {
          file = ../../secrets/shared/coder-db-password.age;
          owner = "postgres";
          group = "postgres";
          mode = "0400";
        };

        age.secrets."coder-env" = {
          file = ../../secrets/shared/coder-env.age;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        environment.etc."coder/db.env" = {
          source = dbSecretPath;
          user = "postgres";
          group = "postgres";
          mode = "0400";
        };

        environment.etc."coder/coder.env" = {
          source = coderSecretPath;
          user = "root";
          group = "root";
          mode = "0400";
        };

        systemd = {
          tmpfiles.rules = [
            "d ${cfg.dataDir} 0750 root root -"
            "d /etc/coder 0750 root root -"
          ];

          services =
            {
              ${containerServiceName} = {
                after =
                  [
                    "postgresql.service"
                    "coder-postgres-password.service"
                    "run-agenix.d.mount"
                  ]
                  ++ optional (cfg.dockerSocketPath != null) "docker.service";
                requires =
                  [
                    "postgresql.service"
                    "coder-postgres-password.service"
                    "run-agenix.d.mount"
                  ]
                  ++ optional (cfg.dockerSocketPath != null) "docker.service";
              };

              "coder-postgres-password" = {
                description = "Set password for the Coder PostgreSQL user";
                unitConfig.RequiresMountsFor = [
                  cfg.databaseEnvFile
                  cfg.environmentFile
                  dbSecretPath
                  coderSecretPath
                ];
                wants = [
                  "postgresql.service"
                  "run-agenix.d.mount"
                ];
                after = [
                  "postgresql.service"
                  "run-agenix.d.mount"
                ];
                requires = [
                  "postgresql.service"
                  "run-agenix.d.mount"
                ];
                wantedBy = ["multi-user.target"];
                partOf = [containerUnit];
                serviceConfig = {
                  Type = "oneshot";
                  User = "postgres";
                  Group = "postgres";
                  ExecStart = setPasswordScript;
                };
              };
            }
            // lib.optionalAttrs cfg.autoRegisterTemplates {
              "coder-register-templates" = {
                description = "Register Egoengine templates with Coder";
                wants = [containerUnit];
                after = [
                  containerUnit
                  "network-online.target"
                  "agenix.service"
                ];
                requires = [containerUnit];
                partOf = [containerUnit];
                wantedBy = ["multi-user.target"];
                path = [
                  pkgs.coreutils
                  pkgs.coder
                  pkgs.git
                ];
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = templateRegistrationScript;
                  Restart = "on-failure";
                  RestartSec = 30;
                };
              };
            };
        };

        services.postgresql = {
          enable = true;
          package = cfg.postgresqlPackage;
          ensureDatabases = [cfg.databaseName];
          ensureUsers = [
            {
              name = cfg.databaseUser;
              ensureDBOwnership = true;
            }
          ];
          settings = {
            listen_addresses = mkForce "127.0.0.1";
          };
          authentication = mkOverride 50 ''
            local   all             all                                     peer
            host    all             all             127.0.0.1/32            scram-sha-256
            host    all             all             ::1/128                 scram-sha-256
          '';
        };

        virtualisation.oci-containers.backend = mkDefault (
          if cfg.dockerSocketPath != null
          then "docker"
          else "podman"
        );

        virtualisation.oci-containers.containers.${cfg.containerName} = {
          inherit (cfg) image;
          autoStart = true;
          extraOptions =
            ["--network=host"]
            ++ optional (cfg.dockerSocketPath != null) "--user=root"
            ++ optional (cfg.dockerSocketPath != null && dockerGroupGid != null)
            "--group-add=${toString dockerGroupGid}";
          environment =
            (optionalAttrs (cfg.accessUrl != null) {
              CODER_ACCESS_URL = cfg.accessUrl;
            })
            // {
              CODER_HTTP_ADDRESS = "0.0.0.0:${toString cfg.port}";
            }
            // optionalAttrs (cfg.dockerSocketPath != null) {
              CODER_PROVISIONER_DOCKER_HOST = "unix://${cfg.dockerSocketPath}";
            };
          environmentFiles = [cfg.environmentFile];
          volumes =
            [
              "${cfg.dataDir}:/var/lib/coder"
            ]
            ++ optional (cfg.dockerSocketPath != null)
            "${cfg.dockerSocketPath}:${cfg.dockerSocketPath}";
        };
      }
    ]);
}
