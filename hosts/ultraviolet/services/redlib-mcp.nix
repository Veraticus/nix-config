{pkgs, config, ...}: {
  # Declare the secrets
  age.secrets."access-client-id" = {
    file = ../../../secrets/hosts/ultraviolet/access-client-id.age;
    owner = "redlib-mcp";
    group = "redlib-mcp";
    mode = "0400";
  };

  age.secrets."access-client-secret" = {
    file = ../../../secrets/hosts/ultraviolet/access-client-secret.age;
    owner = "redlib-mcp";
    group = "redlib-mcp";
    mode = "0400";
  };

  age.secrets."mcp-jwt-secret" = {
    file = ../../../secrets/hosts/ultraviolet/mcp-jwt-secret.age;
    owner = "redlib-mcp";
    group = "redlib-mcp";
    mode = "0400";
  };

  # Create dedicated user (needed for secret ownership)
  users.users.redlib-mcp = {
    isSystemUser = true;
    group = "redlib-mcp";
  };
  users.groups.redlib-mcp = {};

  # Runs on port 8000 - HTTP transport with OAuth
  systemd.services.redlib-mcp = {
    description = "Redlib MCP Server - Reddit API for Claude";
    after = ["network.target" "redlib.service"];
    wants = ["redlib.service"];
    wantedBy = ["multi-user.target"];

    environment = {
      REDLIB_URL = "http://localhost:8091";
      ACCESS_CONFIG_URL = "https://husbuddies.cloudflareaccess.com/cdn-cgi/access/sso/oidc/bd358711b54c48b72c9b558891d12257d45be83f69d4268247091b07916b66f2/.well-known/openid-configuration";
      MCP_SERVER_URL = "https://redlib-mcp.husbuddies.gay";
      MCP_SERVER_HOST = "127.0.0.1";
      MCP_SERVER_PORT = "8000";
    };

    serviceConfig = {
      Type = "simple";
      User = "redlib-mcp";
      Group = "redlib-mcp";
      Restart = "always";
      RestartSec = "5s";

      # Load secrets as credentials
      LoadCredential = [
        "access-client-id:${config.age.secrets."access-client-id".path}"
        "access-client-secret:${config.age.secrets."access-client-secret".path}"
        "mcp-jwt-secret:${config.age.secrets."mcp-jwt-secret".path}"
      ];

      # State directory for OAuth token storage
      StateDirectory = "redlib-mcp";

      # Security hardening
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };

    # Load secrets and run the HTTP server with OAuth
    script = ''
      export ACCESS_CLIENT_ID=$(cat $CREDENTIALS_DIRECTORY/access-client-id)
      export ACCESS_CLIENT_SECRET=$(cat $CREDENTIALS_DIRECTORY/access-client-secret)
      export MCP_JWT_SECRET=$(cat $CREDENTIALS_DIRECTORY/mcp-jwt-secret)
      export HOME=/var/lib/redlib-mcp
      exec ${pkgs.redlib-mcp}/bin/redlib-mcp-server
    '';
  };
}
