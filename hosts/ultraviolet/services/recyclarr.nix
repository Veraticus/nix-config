# Recyclarr: automatically sync TRaSH Guide quality profiles to Sonarr/Radarr.
# Replaces the manual configure-arr-optimal.sh script with community-maintained
# profiles that are regularly updated.
{pkgs, ...}: let
  recyclarrConfig = pkgs.writeText "recyclarr.yml" ''
    sonarr:
      tv:
        base_url: http://localhost:8989
        api_key: !secret sonarr_apikey
        delete_old_custom_formats: true
        replace_existing_custom_formats: true
        include:
          - template: sonarr-quality-definition-series
          - template: sonarr-v4-quality-profile-web-1080p
          - template: sonarr-v4-custom-formats-web-1080p
          - template: sonarr-v4-quality-profile-web-2160p
          - template: sonarr-v4-custom-formats-web-2160p

    radarr:
      movies:
        base_url: http://localhost:7878
        api_key: !secret radarr_apikey
        delete_old_custom_formats: true
        replace_existing_custom_formats: true
        include:
          - template: radarr-quality-definition-movie
          - template: radarr-quality-profile-hd-bluray-web
          - template: radarr-custom-formats-hd-bluray-web
          - template: radarr-quality-profile-uhd-bluray-web
          - template: radarr-custom-formats-uhd-bluray-web
  '';
in {
  systemd.services.recyclarr = {
    description = "Sync TRaSH Guide quality profiles to Sonarr/Radarr";
    after = ["sonarr.service" "radarr.service"];
    wants = ["sonarr.service" "radarr.service"];

    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "recyclarr";
      ExecStart = pkgs.writeShellScript "recyclarr-sync" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        CONFIG_DIR="/var/lib/recyclarr"

        # Read API keys from *arr config files
        SONARR_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<ApiKey>)[^<]+' /var/lib/sonarr/.config/NzbDrone/config.xml 2>/dev/null || echo "")
        RADARR_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<ApiKey>)[^<]+' /var/lib/radarr/.config/Radarr/config.xml 2>/dev/null || echo "")

        if [[ -z "$SONARR_KEY" || -z "$RADARR_KEY" ]]; then
          echo "ERROR: Could not read API keys. Are Sonarr and Radarr running?"
          exit 1
        fi

        # Generate secrets file
        cat > "$CONFIG_DIR/secrets.yml" <<EOF
        sonarr_apikey: $SONARR_KEY
        radarr_apikey: $RADARR_KEY
        EOF

        # Copy config
        cp ${recyclarrConfig} "$CONFIG_DIR/recyclarr.yml"

        # Wait for APIs to be responsive
        for svc in "localhost:8989" "localhost:7878"; do
          until ${pkgs.curl}/bin/curl -s -m 5 "http://$svc/ping" >/dev/null 2>&1; do
            echo "Waiting for $svc..."
            sleep 5
          done
        done

        echo "Syncing TRaSH Guide profiles..."
        ${pkgs.recyclarr}/bin/recyclarr sync \
          --config "$CONFIG_DIR/recyclarr.yml" \
          --app-data "$CONFIG_DIR"
      '';
    };
  };

  systemd.timers.recyclarr = {
    description = "Sync TRaSH Guide profiles daily at 5:00 AM";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };
}
