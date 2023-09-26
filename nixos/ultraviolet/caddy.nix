{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.myCaddy;

  virtualHosts = attrValues cfg.virtualHosts;
  acmeVHosts = filter (hostOpts: hostOpts.useACMEHost != null) virtualHosts;

  mkVHostConf = hostOpts:
    let
      sslCertDir = config.security.acme.certs.${hostOpts.useACMEHost}.directory;
    in
    ''
      ${hostOpts.hostName} ${concatStringsSep " " hostOpts.serverAliases} {
        bind ${concatStringsSep " " hostOpts.listenAddresses}
        ${optionalString (hostOpts.useACMEHost != null) "tls ${sslCertDir}/cert.pem ${sslCertDir}/key.pem"}
        log {
          ${hostOpts.logFormat}
        }

        ${hostOpts.extraConfig}
      }
    '';

  configFile =
    let
      Caddyfile = pkgs.writeTextDir "Caddyfile" ''
        {
          ${cfg.globalConfig}
        }
        ${cfg.extraConfig}
      '';

      Caddyfile-formatted = pkgs.runCommand "Caddyfile-formatted" { nativeBuildInputs = [ cfg.package cfg.mullvadVpnPackage ]; } ''
        mkdir -p $out
        cp --no-preserve=mode ${Caddyfile}/Caddyfile $out/Caddyfile
        caddy fmt --overwrite $out/Caddyfile
      '';
    in
    "${if pkgs.stdenv.buildPlatform == pkgs.stdenv.hostPlatform then Caddyfile-formatted else Caddyfile}/Caddyfile";

  acmeHosts = unique (catAttrs "useACMEHost" acmeVHosts);

  mkCertOwnershipAssertion = import ../../../security/acme/mk-cert-ownership-assertion.nix;
in
{
  imports = [
    (mkRemovedOptionModule [ "services" "caddy" "agree" ] "this option is no longer necessary for Caddy 2")
    (mkRenamedOptionModule [ "services" "caddy" "ca" ] [ "services" "caddy" "acmeCA" ])
    (mkRenamedOptionModule [ "services" "caddy" "config" ] [ "services" "caddy" "extraConfig" ])
  ];

  # interface
  options.services.caddy = {
    enable = mkEnableOption (lib.mdDoc "Caddy web server");

    user = mkOption {
      default = "caddy";
      type = types.str;
      description = lib.mdDoc ''
        User account under which caddy runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the Caddy service starts.
        :::
      '';
    };

    group = mkOption {
      default = "caddy";
      type = types.str;
      description = lib.mdDoc ''
        Group account under which caddy runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the Caddy service starts.
        :::
      '';
    };

    package = mkOption {
      default = pkgs.caddy;
      defaultText = literalExpression "pkgs.caddy";
      type = types.package;
      description = lib.mdDoc ''
        Caddy package to use.
      '';
    };

    mullvadVpnPackage = mkOption {
      default = pkgs.mullvad-vpn;
      defaultText = literalExpression "pkgs.mullvad-vpn";
      type = types.package;
      description = lib.mdDoc ''
        MullvadVPN package to use.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/caddy";
      description = lib.mdDoc ''
        The data directory for caddy.

        ::: {.note}
        If left as the default value this directory will automatically be created
        before the Caddy server starts, otherwise you are responsible for ensuring
        the directory exists with appropriate ownership and permissions.

        Caddy v2 replaced `CADDYPATH` with XDG directories.
        See <https://caddyserver.com/docs/conventions#file-locations>.
        :::
      '';
    };

    logDir = mkOption {
      type = types.path;
      default = "/var/log/caddy";
      description = lib.mdDoc ''
        Directory for storing Caddy access logs.

        ::: {.note}
        If left as the default value this directory will automatically be created
        before the Caddy server starts, otherwise the sysadmin is responsible for
        ensuring the directory exists with appropriate ownership and permissions.
        :::
      '';
    };

    logFormat = mkOption {
      type = types.lines;
      default = ''
        level ERROR
      '';
      example = literalExpression ''
        mkForce "level INFO";
      '';
      description = lib.mdDoc ''
        Configuration for the default logger. See
        <https://caddyserver.com/docs/caddyfile/options#log>
        for details.
      '';
    };

    configFile = mkOption {
      type = types.path;
      default = configFile;
      defaultText = "A Caddyfile automatically generated by values from services.caddy.*";
      example = literalExpression ''
        pkgs.writeTextDir "Caddyfile" '''
          example.com

          root * /var/www/wordpress
          php_fastcgi unix//run/php/php-version-fpm.sock
          file_server
        ''';
      '';
      description = lib.mdDoc ''
        Override the configuration file used by Caddy. By default,
        NixOS generates one automatically.
      '';
    };

    adapter = mkOption {
      default = null;
      example = literalExpression "nginx";
      type = with types; nullOr str;
      description = lib.mdDoc ''
        Name of the config adapter to use.
        See <https://caddyserver.com/docs/config-adapters>
        for the full list.

        If `null` is specified, the `--adapter` argument is omitted when
        starting or restarting Caddy. Notably, this allows specification of a
        configuration file in Caddy's native JSON format, as long as the
        filename does not start with `Caddyfile` (in which case the `caddyfile`
        adapter is implicitly enabled). See
        <https://caddyserver.com/docs/command-line#caddy-run> for details.

        ::: {.note}
        Any value other than `null` or `caddyfile` is only valid when providing
        your own `configFile`.
        :::
      '';
    };

    resume = mkOption {
      default = false;
      type = types.bool;
      description = lib.mdDoc ''
        Use saved config, if any (and prefer over any specified configuration passed with `--config`).
      '';
    };

    globalConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        debug
        servers {
          protocol {
            experimental_http3
          }
        }
      '';
      description = lib.mdDoc ''
        Additional lines of configuration appended to the global config section
        of the `Caddyfile`.

        Refer to <https://caddyserver.com/docs/caddyfile/options#global-options>
        for details on supported values.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        example.com {
          encode gzip
          log
          root /srv/http
        }
      '';
      description = lib.mdDoc ''
        Additional lines of configuration appended to the automatically
        generated `Caddyfile`.
      '';
    };

    virtualHosts = mkOption {
      type = with types; attrsOf (submodule (import ./vhost-options.nix { inherit cfg; }));
      default = { };
      example = literalExpression ''
        {
          "hydra.example.com" = {
            serverAliases = [ "www.hydra.example.com" ];
            extraConfig = '''
              encode gzip
              root /srv/http
            ''';
          };
        };
      '';
      description = lib.mdDoc ''
        Declarative specification of virtual hosts served by Caddy.
      '';
    };

    acmeCA = mkOption {
      default = "https://acme-v02.api.letsencrypt.org/directory";
      example = "https://acme-staging-v02.api.letsencrypt.org/directory";
      type = with types; nullOr str;
      description = lib.mdDoc ''
        The URL to the ACME CA's directory. It is strongly recommended to set
        this to Let's Encrypt's staging endpoint for testing or development.

        Set it to `null` if you want to write a more
        fine-grained configuration manually.
      '';
    };

    email = mkOption {
      default = null;
      type = with types; nullOr str;
      description = lib.mdDoc ''
        Your email address. Mainly used when creating an ACME account with your
        CA, and is highly recommended in case there are problems with your
        certificates.
      '';
    };

  };

  # implementation
  config = mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.configFile == configFile -> cfg.adapter == "caddyfile" || cfg.adapter == null;
        message = "To specify an adapter other than 'caddyfile' please provide your own configuration via `services.caddy.configFile`";
      }
    ] ++ map
      (name: mkCertOwnershipAssertion {
        inherit (cfg) group user;
        cert = config.security.acme.certs.${name};
        groups = config.users.groups;
      })
      acmeHosts;

    services.caddy.extraConfig = concatMapStringsSep "\n" mkVHostConf virtualHosts;
    services.caddy.globalConfig = ''
      ${optionalString (cfg.email != null) "email ${cfg.email}"}
      ${optionalString (cfg.acmeCA != null) "acme_ca ${cfg.acmeCA}"}
      log {
        ${cfg.logFormat}
      }
    '';

    # https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size
    boot.kernel.sysctl."net.core.rmem_max" = mkDefault 2500000;

    systemd.packages = [ cfg.package cfg.mullvadVpnPackage ];
    systemd.services.caddy = {
      wants = map (hostOpts: "acme-finished-${hostOpts.useACMEHost}.target") acmeVHosts;
      after = map (hostOpts: "acme-selfsigned-${hostOpts.useACMEHost}.service") acmeVHosts;
      before = map (hostOpts: "acme-${hostOpts.useACMEHost}.service") acmeVHosts;

      wantedBy = [ "multi-user.target" ];
      startLimitIntervalSec = 14400;
      startLimitBurst = 10;

      serviceConfig = {
        # https://www.freedesktop.org/software/systemd/man/systemd.service.html#ExecStart=
        # If the empty string is assigned to this option, the list of commands to start is reset, prior assignments of this option will have no effect.
        ExecStart = [ "" ''${cfg.mullvadVpnPackage}/bin/mullvad-exclude ${cfg.package}/bin/caddy run --config ${cfg.configFile} ${optionalString (cfg.adapter != null) "--adapter ${cfg.adapter}"} ${optionalString cfg.resume "--resume"}'' ];
        ExecReload = [ "" ''${cfg.mullvadVpnPackage}/bin/mullvad-exclude ${cfg.package}/bin/caddy reload --config ${cfg.configFile} ${optionalString (cfg.adapter != null) "--adapter ${cfg.adapter}"} --force'' ];
        ExecStartPre = ''${cfg.mullvadVpnPackage}/bin/mullvad-exclude ${cfg.package}/bin/caddy validate --config ${cfg.configFile} ${optionalString (cfg.adapter != null) "--adapter ${cfg.adapter}"}'';
        User = cfg.user;
        Group = cfg.group;
        ReadWriteDirectories = cfg.dataDir;
        StateDirectory = mkIf (cfg.dataDir == "/var/lib/caddy") [ "caddy" ];
        LogsDirectory = mkIf (cfg.logDir == "/var/log/caddy") [ "caddy" ];
        Restart = "on-abnormal";

        # TODO: attempt to upstream these options
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectHome = true;
      };
    };

    users.users = optionalAttrs (cfg.user == "caddy") {
      caddy = {
        group = cfg.group;
        uid = config.ids.uids.caddy;
        home = cfg.dataDir;
      };
    };

    users.groups = optionalAttrs (cfg.group == "caddy") {
      caddy.gid = config.ids.gids.caddy;
    };

    security.acme.certs =
      let
        certCfg = map
          (useACMEHost: nameValuePair useACMEHost {
            group = mkDefault cfg.group;
            reloadServices = [ "caddy.service" ];
          })
          acmeHosts;
      in
      listToAttrs certCfg;

  };
}
