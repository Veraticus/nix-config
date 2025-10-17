{ lib, config, pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    extraConfig = ''
      # Enable Kitty terminal integration
      # Let the terminal type be passed through properly
      SendEnv TERM COLORTERM
      
      # Performance optimizations
      Compression yes
      TCPKeepAlive yes
      
      # Use faster ciphers for better responsiveness
      Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
      
      # Reuse connections for faster subsequent connections
      ControlMaster auto
      ControlPath ~/.ssh/control-%C
      ControlPersist 2h
      
      # Additional latency optimizations
      ServerAliveCountMax 3
      ConnectTimeout 10
      
      # Disable unnecessary features that add latency
      
      # Enable pipelining for faster command execution
      EnableEscapeCommandline yes
      
      # Use IPQoS for interactive sessions
      IPQoS lowdelay throughput
    '';

    matchBlocks = {
      "*" = {
        forwardAgent = true;
        serverAliveInterval = 60;
      };

      "ultraviolet" = {
        hostname = "ultraviolet";
        user = "joshsymonds";
        forwardX11 = true;
        forwardX11Trusted = true;
      };

      "bluedesert" = {
        hostname = "bluedesert";
        user = "joshsymonds";
        forwardX11 = true;
        forwardX11Trusted = true;
      };

      "echelon" = {
        hostname = "echelon";
        user = "joshsymonds";
        forwardX11 = true;
        forwardX11Trusted = true;
      };
    };
  };
}
