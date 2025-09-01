{ config, pkgs, lib, ... }:
{
  services.home-assistant = {
    enable = true;
    
    extraComponents = [
      # Core functionality
      "default_config"     # Includes most common integrations
      "met"                # Weather (required for onboarding)
      "radio_browser"      # Radio stations
      
      # Your existing smart home devices
      "hue"                # Philips Hue lights
      "ecobee"             # Ecobee thermostat
      "zwave_js"           # Z-Wave via Z-Wave JS UI on bluedesert
      
      # Future expansion ready
      "zha"                # Zigbee Home Automation (if you add Zigbee later)
      "mqtt"               # MQTT (if you add it later)
      
      # Local media integration
      "jellyfin"           # Your Jellyfin server
      
      # System monitoring
      "systemmonitor"      # Monitor ultraviolet's resources
      "uptime"            
      
      # Mobile app support
      "mobile_app"         # For Home Assistant companion app
      "webhook"            # For app communications
      
      # Automation helpers
      "input_boolean"
      "input_button"
      "input_datetime"
      "input_number"
      "input_select"
      "input_text"
      "timer"
      "counter"
      "schedule"
    ];
    
    config = {
      # Basic configuration
      default_config = {};
      
      homeassistant = {
        name = "Home";
        # Location is loaded from secrets.yaml to keep it out of git
        latitude = "!secret latitude";
        longitude = "!secret longitude";
        elevation = "!secret elevation";
        unit_system = "us_customary";  # Use Fahrenheit, miles, etc.
        time_zone = "America/Los_Angeles";
        currency = "USD";
        country = "US";
      };
      
      # Enable the web interface
      http = {
        server_host = "::1";  # Listen on localhost only (Caddy will proxy)
        trusted_proxies = [ "::1" "127.0.0.1" ];
        use_x_forwarded_for = true;
      };
      
      # Configure recorder for history (30 days default)
      recorder = {
        purge_keep_days = 30;
        exclude = {
          domains = [
            "automation"
            "updater"
          ];
          entity_globs = [
            "sensor.weather_*"
          ];
        };
      };
      
      # Z-Wave JS configuration to connect to bluedesert
      zwave_js = {
        # This will be configured through the UI
        # URL: ws://bluedesert:3000 or ws://172.31.0.201:3000
      };
      
      # Frontend themes
      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      
      # Logging
      logger = {
        default = "warning";
        logs = {
          "homeassistant.components.zwave_js" = "info";
        };
      };
      
      # Automation engine (keep automations in UI for easy editing)
      automation = "!include automations.yaml";
      script = "!include scripts.yaml";
      scene = "!include scenes.yaml";
    };
    
    # Make configuration writable so you can edit from the UI
    configWritable = true;
    
    # Configure directory for additional YAML files
    configDir = "/var/lib/hass";
    
    # Open firewall port (only localhost, Caddy handles external)
    openFirewall = false;
  };
  
  # Add Home Assistant to Caddy reverse proxy
  services.caddy.virtualHosts."homeassistant.home.husbuddies.gay" = {
    extraConfig = ''
      reverse_proxy localhost:8123 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
      }
      import cloudflare
    '';
  };
  
  # Create necessary directories and files
  systemd.tmpfiles.rules = [
    "d /var/lib/hass/themes 0755 hass hass -"
    "d /etc/homepage/keys 0755 root root -"
  ];
  
  # Create a secrets.yaml template for Home Assistant
  # This file can be edited after deployment to add your actual secrets
  environment.etc."hass-secrets.yaml" = {
    mode = "0600";
    user = "hass";
    text = ''
      # Home Assistant Secrets File
      # IMPORTANT: Edit this file at /var/lib/hass/secrets.yaml after deployment
      # with your actual location and API keys
      
      # Location data - MUST UPDATE with your actual location
      # Find your coordinates at https://www.latlong.net/
      latitude: 0.0
      longitude: 0.0  
      elevation: 0
      
      # Z-Wave JS WebSocket URL (update if using different host/port)
      zwave_js_url: ws://172.31.0.201:3000
      
      # API Keys (add as needed)
      # ecobee_api_key: your-ecobee-api-key
      # openweathermap_api_key: your-openweathermap-key
      
      # Notification servers
      ntfy_server: http://172.31.0.201:8093
      # Use random strings for topics for security
      ntfy_topic_alerts: home-alerts-CHANGEME
      ntfy_topic_water: water-sensors-CHANGEME
      ntfy_topic_security: door-sensors-CHANGEME
    '';
  };
  
  # Copy secrets file to Home Assistant directory on startup
  systemd.services.home-assistant.preStart = lib.mkAfter ''
    # Copy secrets file if it doesn't exist
    if [ ! -f /var/lib/hass/secrets.yaml ]; then
      cp /etc/hass-secrets.yaml /var/lib/hass/secrets.yaml
      chown hass:hass /var/lib/hass/secrets.yaml
      chmod 600 /var/lib/hass/secrets.yaml
      echo "Created secrets.yaml - please edit it with your actual values"
    fi
  '';
  
  # Note: After deploying, you'll need to:
  # 1. UPDATE LOCATION: Edit /var/lib/hass/secrets.yaml with your actual latitude/longitude
  # 2. Access Home Assistant at https://homeassistant.home.husbuddies.gay
  # 3. Complete the onboarding process
  # 4. Update location in UI: Settings -> System -> General
  # 5. Add integrations:
  #    - Z-Wave JS: URL ws://bluedesert:3000 or ws://172.31.0.201:3000
  #    - Philips Hue: Will auto-discover or add manually
  #    - Ecobee: Use the cloud integration with OAuth
  #    - Jellyfin: Server at http://localhost:8096
  # 6. Generate Long-Lived Access Token for Homepage:
  #    - Profile -> Security -> Long-Lived Access Tokens
  #    - Save to /etc/homepage/keys/homeassistant-api-key
  # 7. Install the companion app on your phone
  # 8. Set up ntfy in automations for push notifications
}