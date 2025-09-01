{ config, pkgs, ... }:
{
  # ntfy for push notifications (lightweight, no database)
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "http://bluedesert:8093";  # Required setting
      listen-http = ":8093";
      cache-file = "/var/cache/ntfy/cache.db";
      cache-duration = "12h";
      behind-proxy = false;
      
      # Topics don't require auth by default - security through obscurity
      # Use long random topic names for security (e.g., "home-alerts-x7k9m2p")
    };
  };

  # Z-Wave JS UI (formerly zwavejs2mqtt) in container
  # Provides both Z-Wave control UI and WebSocket server for Home Assistant
  virtualisation.oci-containers.containers.zwave-js-ui = {
    image = "zwavejs/zwave-js-ui:9.27.0";
    ports = [
      "8091:8091"  # Web UI for Z-Wave management
      "3000:3000"  # WebSocket server for Home Assistant
    ];
    volumes = [
      "/var/lib/zwave-js-ui:/usr/src/app/store"
    ];
    environment = {
      TZ = "America/Los_Angeles";
    };
    extraOptions = [
      "--network=host"
      # Map the Z-Wave USB device when you plug it in
      # Uncomment and adjust when you have the USB stick:
      # "--device=/dev/ttyUSB0:/dev/zwave"
      # Or use --device=/dev/serial/by-id/... for more stable naming
    ];
  };

  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d /var/lib/zwave-js-ui 0755 root root -"
    "d /var/cache/ntfy 0755 ntfy ntfy -"
  ];

  # Open firewall ports
  networking.firewall.allowedTCPPorts = [
    3000  # Z-Wave JS WebSocket for Home Assistant
    8091  # Z-Wave JS UI for management
    8093  # ntfy for notifications
  ];

  # Podman for containers (already enabled in common.nix usually)
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };
  
  # Note: When you get your Z-Wave USB stick:
  # 1. Plug it in and run: ls -la /dev/serial/by-id/
  # 2. Find your device (usually something like usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_...)
  # 3. Update the extraOptions above to map it
  # 4. The container will handle all Z-Wave protocol details
}