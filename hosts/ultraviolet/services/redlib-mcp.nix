{pkgs, ...}: {
  # Runs on port 8000 (FastMCP default) - configure tunnel accordingly
  systemd.services.redlib-mcp = {
    description = "Redlib MCP Server - Reddit API for Claude";
    after = ["network.target" "redlib.service"];
    wants = ["redlib.service"];
    wantedBy = ["multi-user.target"];

    environment = {
      REDLIB_URL = "http://localhost:8091";
      MCP_TRANSPORT = "sse";
      MCP_ALLOWED_HOSTS = "localhost:*,127.0.0.1:*,redlib-mcp.husbuddies.gay:*";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.redlib-mcp}/bin/redlib-mcp";
      Restart = "always";
      RestartSec = "5s";

      # Security hardening
      DynamicUser = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}
