{ config, pkgs, lib, ... }:
{
  # Add zwave-js-ui user to dialout group for device access
  users.users.zwave-js-ui = {
    isSystemUser = true;
    group = "zwave-js-ui";
    extraGroups = [ "dialout" ];
  };
  users.groups.zwave-js-ui = {};

  # ntfy for push notifications (lightweight, no database)
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "http://bluedesert:8093";  # Required setting
      listen-http = ":8093";
      cache-file = "/var/lib/ntfy-sh/cache.db";  # Use StateDirectory instead of /var/cache
      cache-duration = "12h";
      behind-proxy = false;
      
      # Topics don't require auth by default - security through obscurity
      # Use long random topic names for security (e.g., "home-alerts-x7k9m2p")
    };
  };

  # Z-Wave JS UI - native NixOS service
  services.zwave-js-ui = {
    enable = true;
    serialPort = "/dev/serial/by-id/usb-Nabu_Casa_ZWA-2_80B54EE5E010-if00";
    
    settings = {
      HOST = "0.0.0.0";  # Listen on all interfaces
      PORT = "8091";     # Web UI port
    };
  };

  # Override systemd service to fix device access
  systemd.services.zwave-js-ui.serviceConfig = {
    # Disable the chroot to allow device access
    RootDirectory = lib.mkForce "";
    # Keep other sandboxing but allow device access
    PrivateDevices = lib.mkForce false;
    DevicePolicy = lib.mkForce "auto";
    # Use the static user instead of dynamic user
    DynamicUser = lib.mkForce false;
    User = "zwave-js-ui";
    Group = "zwave-js-ui";
  };

  # Open firewall ports
  networking.firewall.allowedTCPPorts = [
    3000  # Z-Wave JS WebSocket for Home Assistant
    8091  # Z-Wave JS UI for management
    8093  # ntfy for notifications
  ];
}