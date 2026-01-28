{pkgs, config, ...}: {
  # Shared group so both invidious and companion can read the secret
  users.groups.invidious-shared = {};

  # Agenix secret for the shared Companion/Invidious key (16 chars)
  age.secrets."invidious-companion-key" = {
    file = ../../../secrets/hosts/ultraviolet/invidious-companion-key.age;
    owner = "root";
    group = "invidious-shared";
    mode = "0440";
  };

  # Invidious via stock NixOS module
  services.invidious = {
    enable = true;
    domain = "invidious.home.husbuddies.gay";
    port = 3030;

    database.createLocally = true;

    extraSettingsFile = "/run/invidious/extra-settings.json";

    settings = {
      https_only = true;
      external_port = 443;

      registration_enabled = false;
      login_enabled = true;

      invidious_companion = [
        {
          private_url = "http://127.0.0.1:8282/companion";
        }
      ];

      popular_enabled = true;
      quality = "dash";
    };
  };

  # Add invidious user to shared group and inject companion key at preStart
  systemd.services.invidious = {
    preStart = ''
      mkdir -p /run/invidious
      echo "{\"invidious_companion_key\": \"$(cat ${config.age.secrets."invidious-companion-key".path})\"}" > /run/invidious/extra-settings.json
      chmod 600 /run/invidious/extra-settings.json
    '';
    serviceConfig = {
      RuntimeDirectory = "invidious";
      SupplementaryGroups = ["invidious-shared"];
    };
  };

  # Companion dedicated user
  users.users.invidious-companion = {
    isSystemUser = true;
    group = "invidious-companion";
    extraGroups = ["invidious-shared"];
  };
  users.groups.invidious-companion = {};

  # Invidious Companion systemd service
  systemd.services.invidious-companion = {
    description = "Invidious Companion - YouTube stream handler via youtube.js";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "invidious-companion";
      Group = "invidious-companion";
      SupplementaryGroups = ["invidious-shared"];
      Restart = "always";
      RestartSec = "5s";

      LoadCredential = [
        "secret-key:${config.age.secrets."invidious-companion-key".path}"
      ];

      StateDirectory = "invidious-companion";
      CacheDirectory = "invidious-companion";

      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = ["/var/tmp"];
    };

    script = ''
      export SERVER_SECRET_KEY=$(cat $CREDENTIALS_DIRECTORY/secret-key)
      export HOST=127.0.0.1
      export PORT=8282
      export CACHE_DIRECTORY=/var/tmp
      exec ${pkgs.invidious-companion}/bin/invidious-companion
    '';
  };

  # Caddy reverse proxy
  services.caddy.virtualHosts = {
    "invidious.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* 127.0.0.1:3030
      import cloudflare
    '';
    "invidious-companion.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* 127.0.0.1:8282
      import cloudflare
    '';
  };
}
