_: {
  systemd.tmpfiles.rules = [
    "d /etc/homepage/keys 0755 root root -"
  ];

  environment = {
    etc = {
      "homepage/config/settings.yaml" = {
        mode = "0644";
        text = ''
          providers:
            openweathermap: openweathermapapikey
            weatherapi: weatherapiapikey
        '';
      };

      "homepage/config/bookmarks.yaml" = {
        mode = "0644";
        text = '''';
      };

      "homepage/config/widgets.yaml" = {
        mode = "0644";
        text = ''
          - openmeteo:
              label: "Santa Barbara, CA"
              latitude: 34.4208
              longitude: 119.6982
              units: imperial
              cache: 5 # Time in minutes to cache API responses, to stay within limits
          - resources:
              cpu: true
              memory: true
              disk: /
          - datetime:
              format:
                dateStyle: long
                timeStyle: short
                hourCycle: h23
        '';
      };

      "homepage/config/services.yaml" = {
        mode = "0644";
        text = ''
          - Home Automation:
            - Home Assistant:
                icon: home-assistant.png
                href: https://homeassistant.home.husbuddies.gay
                description: Home automation hub
                widget:
                  type: homeassistant
                  url: http://127.0.0.1:8123
                  key: {{HOMEPAGE_FILE_HOMEASSISTANT_API_KEY}}
          - Media Management:
            - Jellyseerr:
                icon: jellyseerr.png
                href: https://jellyseerr.home.husbuddies.gay
                description: Media discovery
                widget:
                  type: jellyseerr
                  url: http://127.0.0.1:5055
                  key: {{HOMEPAGE_FILE_JELLYSEERR_API_KEY}}
            - Sonarr:
                icon: sonarr.png
                href: https://sonarr.home.husbuddies.gay
                description: Series management
                widget:
                  type: sonarr
                  url: http://127.0.0.1:8989
                  key: {{HOMEPAGE_FILE_SONARR_API_KEY}}
            - Radarr:
                icon: radarr.png
                href: https://radarr.home.husbuddies.gay
                description: Movie management
                widget:
                  type: radarr
                  url: http://127.0.0.1:7878
                  key: {{HOMEPAGE_FILE_RADARR_API_KEY}}
            - Readarr:
                icon: readarr.png
                href: https://readarr.home.husbuddies.gay
                description: Book management
                widget:
                  type: readarr
                  url: http://127.0.0.1:8787
                  key: {{HOMEPAGE_FILE_READARR_API_KEY}}
            - Bazarr:
                icon: bazarr.png
                href: https://bazarr.home.husbuddies.gay
                description: Subtitle Management
                widget:
                  type: bazarr
                  url: http://127.0.0.1:6767
                  key: {{HOMEPAGE_FILE_BAZARR_API_KEY}}
          - Media:
            - Jellyfin:
                icon: jellyfin.png
                href: https://jellyfin.home.husbuddies.gay
                description: Movie management
                widget:
                  type: jellyfin
                  url: http://127.0.0.1:8096
                  key: {{HOMEPAGE_FILE_JELLYFIN_API_KEY}}
            - SABnzbd:
                icon: sabnzbd.png
                href: https://sabnzbd.home.husbuddies.gay
                description: Usenet client
                widget:
                  type: sabnzbd
                  url: http://127.0.0.1:8080
                  key: {{HOMEPAGE_FILE_SABNZBD_API_KEY}}
          - Network:
            - NextDNS:
                icon: nextdns.png
                href: https://my.nextdns.io
                description: DNS Resolution
                widget:
                  type: nextdns
                  profile: 381116
                  key: {{HOMEPAGE_FILE_NEXTDNS_API_KEY}}
        '';
      };
    };
  };

  virtualisation.oci-containers.containers.homepage = {
    image = "ghcr.io/gethomepage/homepage:v0.10.9";
    ports = ["3000:3000"];
    volumes = [
      "/etc/homepage/config:/app/config"
      "/etc/homepage/keys:/app/keys"
    ];
    environment = {
      HOMEPAGE_FILE_SONARR_API_KEY = "/app/keys/sonarr-api-key";
      HOMEPAGE_FILE_BAZARR_API_KEY = "/app/keys/bazarr-api-key";
      HOMEPAGE_FILE_RADARR_API_KEY = "/app/keys/radarr-api-key";
      HOMEPAGE_FILE_READARR_API_KEY = "/app/keys/readarr-api-key";
      HOMEPAGE_FILE_JELLYFIN_API_KEY = "/app/keys/jellyfin-api-key";
      HOMEPAGE_FILE_NEXTDNS_API_KEY = "/app/keys/nextdns-api-key";
      HOMEPAGE_FILE_JELLYSEERR_API_KEY = "/app/keys/jellyseerr-api-key";
      HOMEPAGE_FILE_SABNZBD_API_KEY = "/app/keys/sabnzbd-api-key";
      HOMEPAGE_FILE_HOMEASSISTANT_API_KEY = "/app/keys/homeassistant-api-key";
    };
    extraOptions = ["--network=host"];
  };

  services.caddy.virtualHosts."home.husbuddies.gay".extraConfig = ''
    reverse_proxy /* localhost:3000
    import cloudflare
  '';
}
