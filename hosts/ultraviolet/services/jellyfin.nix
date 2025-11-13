{pkgs, ...}: let
  configureJellyfinUsers = pkgs.writeScriptBin "configure-jellyfin-users" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Configuring Jellyfin user policies for direct play..."

    until ${pkgs.curl}/bin/curl -s http://localhost:8096/System/Info >/dev/null 2>&1; do
      echo "Waiting for Jellyfin API..."
      sleep 5
    done

    if [ ! -f /etc/homepage/keys/jellyfin-api-key ]; then
      echo "⚠ Jellyfin API key file not found at /etc/homepage/keys/jellyfin-api-key"
      echo "  Skipping user policy configuration - will retry on next boot"
      exit 0
    fi

    API_KEY=$(tr -d '\n' </etc/homepage/keys/jellyfin-api-key)

    if [ -z "$API_KEY" ]; then
      echo "⚠ Jellyfin API key is empty"
      echo "  Skipping user policy configuration - will retry on next boot"
      exit 0
    fi

    update_user_policy() {
      local username="$1"

      USER_ID=$(${pkgs.curl}/bin/curl -s "http://localhost:8096/Users" \
        -H "X-Emby-Token: $API_KEY" 2>/dev/null | \
        ${pkgs.jq}/bin/jq -r --arg name "$username" '.[] | select(.Name == $name) | .Id' 2>/dev/null)

      if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
        echo "Updating policy for user: $username (ID: $USER_ID)"
        ${pkgs.curl}/bin/curl -X POST "http://localhost:8096/Users/$USER_ID/Policy" \
          -H "X-Emby-Token: $API_KEY" \
          -H "Content-Type: application/json" \
          -d '{
            "EnableVideoPlaybackTranscoding": false,
            "EnablePlaybackRemuxing": false
          }' >/dev/null 2>&1
        echo "  ✓ Disabled transcoding for $username"
      else
        echo "  ⚠ User $username not found (may not be created yet)"
      fi
    }

    ALL_USERS=$(${pkgs.curl}/bin/curl -s "http://localhost:8096/Users" \
      -H "X-Emby-Token: $API_KEY" 2>/dev/null | \
      ${pkgs.jq}/bin/jq -r '.[].Name' 2>/dev/null)

    if [ -z "$ALL_USERS" ]; then
      echo "ℹ No users found in Jellyfin yet"
      echo "  User policies will be configured when users are created"
      exit 0
    fi

    echo "Found users: $(echo $ALL_USERS | tr '\n' ', ')"
    update_user_policy "jellyfin"
    update_user_policy "josh"

    echo "$ALL_USERS" | while read -r username; do
      if [ "$username" != "jellyfin" ] && [ "$username" != "josh" ] && [ -n "$username" ]; then
        echo "Found additional user: $username"
        update_user_policy "$username"
      fi
    done

    echo "Jellyfin user policy configuration complete"
  '';
in {
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    group = "users";
    openFirewall = true;
    user = "jellyfin";
  };

  users.users.jellyfin.extraGroups = ["video" "render"];

  systemd.services."jellyfin-user-policy" = {
    description = "Configure Jellyfin user policies for direct play";
    after = ["jellyfin.service"];
    wants = ["jellyfin.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'sleep 30'";
      ExecStart = "${configureJellyfinUsers}/bin/configure-jellyfin-users";
      StandardOutput = "journal";
      StandardError = "journal";
      User = "root";
    };
    startLimitIntervalSec = 60;
    startLimitBurst = 3;
  };

  systemd.services.jellyfin.preStart = ''
    mkdir -p /var/lib/jellyfin/config
    cat > /var/lib/jellyfin/config/encoding.xml <<'EOF'
    <?xml version="1.0" encoding="utf-8"?>
    <EncodingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <EncodingThreadCount>-1</EncodingThreadCount>
      <TranscodingTempPath>/var/cache/jellyfin/transcodes</TranscodingTempPath>
      <FallbackFontPath />
      <EnableFallbackFont>false</EnableFallbackFont>
      <EnableAudioVbr>false</EnableAudioVbr>
      <DownMixAudioBoost>2</DownMixAudioBoost>
      <DownMixStereoAlgorithm>None</DownMixStereoAlgorithm>
      <MaxMuxingQueueSize>2048</MaxMuxingQueueSize>
      <EnableThrottling>false</EnableThrottling>
      <ThrottleDelaySeconds>180</ThrottleDelaySeconds>
      <EnableSegmentDeletion>true</EnableSegmentDeletion>
      <SegmentKeepSeconds>720</SegmentKeepSeconds>
      <HardwareAccelerationType>vaapi</HardwareAccelerationType>
      <EncoderAppPathDisplay>/nix/store/fvr78yr36anl4h054ph6nz3jpsdm7ank-jellyfin-ffmpeg-7.1.1-6-bin/bin/ffmpeg</EncoderAppPathDisplay>
      <VaapiDevice>/dev/dri/renderD128</VaapiDevice>
      <QsvDevice />
      <EnableTonemapping>false</EnableTonemapping>
      <EnableVppTonemapping>false</EnableVppTonemapping>
      <EnableVideoToolboxTonemapping>false</EnableVideoToolboxTonemapping>
      <TonemappingAlgorithm>bt2390</TonemappingAlgorithm>
      <TonemappingMode>auto</TonemappingMode>
      <TonemappingRange>auto</TonemappingRange>
      <TonemappingDesat>0</TonemappingDesat>
      <TonemappingPeak>100</TonemappingPeak>
      <TonemappingParam>0</TonemappingParam>
      <VppTonemappingBrightness>16</VppTonemappingBrightness>
      <VppTonemappingContrast>1</VppTonemappingContrast>
      <H264Crf>23</H264Crf>
      <H265Crf>28</H265Crf>
      <EncoderPreset>auto</EncoderPreset>
      <DeinterlaceDoubleRate>false</DeinterlaceDoubleRate>
      <DeinterlaceMethod>yadif</DeinterlaceMethod>
      <EnableDecodingColorDepth10Hevc>true</EnableDecodingColorDepth10Hevc>
      <EnableDecodingColorDepth10Vp9>true</EnableDecodingColorDepth10Vp9>
      <EnableDecodingColorDepth10HevcRext>true</EnableDecodingColorDepth10HevcRext>
      <EnableDecodingColorDepth12HevcRext>false</EnableDecodingColorDepth12HevcRext>
      <EnableEnhancedNvdecDecoder>true</EnableEnhancedNvdecDecoder>
      <PreferSystemNativeHwDecoder>true</PreferSystemNativeHwDecoder>
      <EnableIntelLowPowerH264HwEncoder>false</EnableIntelLowPowerH264HwEncoder>
      <EnableIntelLowPowerHevcHwEncoder>false</EnableIntelLowPowerHevcHwEncoder>
      <EnableHardwareEncoding>true</EnableHardwareEncoding>
      <AllowHevcEncoding>true</AllowHevcEncoding>
      <AllowAv1Encoding>false</AllowAv1Encoding>
      <EnableSubtitleExtraction>true</EnableSubtitleExtraction>
      <HardwareDecodingCodecs>
        <string>h264</string>
        <string>hevc</string>
        <string>mpeg2video</string>
        <string>mpeg4</string>
        <string>vc1</string>
        <string>vp8</string>
        <string>vp9</string>
      </HardwareDecodingCodecs>
      <AllowOnDemandMetadataBasedKeyframeExtractionForExtensions>
        <string>mkv</string>
      </AllowOnDemandMetadataBasedKeyframeExtractionForExtensions>
    </EncodingOptions>
    EOF
  '';

  services.caddy.virtualHosts."jellyfin.home.husbuddies.gay".extraConfig = ''
    reverse_proxy /* localhost:8096
    import cloudflare
  '';
}
