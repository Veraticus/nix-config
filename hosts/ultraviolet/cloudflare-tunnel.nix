{ config, pkgs, lib, ... }:
let
  tokenPath = config.age.secrets."cloudflared-token".path;
in
{
  # Install cloudflared package
  environment.systemPackages = with pkgs; [
    cloudflared
  ];
  
  # Create directory for cloudflared
  systemd.tmpfiles.rules = [
    "d /var/lib/cloudflared 0700 cloudflared cloudflared -"
  ];
  
  # Cloudflare Tunnel service using token
  # Routes are configured in the Cloudflare dashboard at:
  # https://one.dash.cloudflare.com/ → Networks → Tunnels → Public Hostname
  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel for secure external access";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "cloudflared";
      Group = "cloudflared";
      Restart = "always";
      RestartSec = "5s";
      # Token-based tunnel (ingress rules configured in Cloudflare dashboard)
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c '${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token $(cat ${lib.escapeShellArg tokenPath})'
      '';
      # Security hardening
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadOnlyPaths = [ tokenPath ];
    };
    
    # Only start if token file exists
    unitConfig = {
      ConditionPathExists = tokenPath;
    };
  };
  
  # Create cloudflared user
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
    home = "/var/lib/cloudflared";
    createHome = true;
  };
  
  users.groups.cloudflared = {};
  
  # Setup documentation
  system.activationScripts.cloudflared-setup = ''
    if [ ! -f /var/lib/cloudflared/README.txt ]; then
      cat > /var/lib/cloudflared/README.txt <<'EOF'
    Cloudflare Tunnel Setup
    ========================
    
    This directory contains the Cloudflare tunnel token.
    DO NOT commit this file to version control!
    
    The tunnel authentication token is supplied via agenix.
    To rotate the token, update secrets/hosts/ultraviolet/cloudflared-token.age\n
    
    For reference, to create a token manually:
      cloudflared tunnel login
      cloudflared tunnel create <tunnel-name>
      cloudflared tunnel token <tunnel-name>
    
    Configure routing in Cloudflare dashboard:
    1. Go to https://one.dash.cloudflare.com/
    2. Navigate to Networks → Tunnels
    3. Click on your tunnel
    4. Go to Public Hostname tab
    5. Add your routes there (e.g., home.husbuddies.gay → http://localhost:8123)
    EOF
      chmod 644 /var/lib/cloudflared/README.txt
    fi
  '';
}
