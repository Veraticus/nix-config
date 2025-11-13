{pkgs, ...}: {
  services.wyoming.faster-whisper = {
    package = pkgs.wyoming-faster-whisper;

    servers = {
      default = {
        enable = true;

        # Model selection - using base model for good balance of speed/accuracy
        # You can change to "tiny-int8" for faster but less accurate, or "small" for better accuracy
        model = "base-int8";

        # English language for better performance - change to "auto" for multilingual
        language = "en";

        # Bind to all interfaces so Home Assistant can connect
        uri = "tcp://0.0.0.0:10300";

        # CPU mode (no GPU on this server)
        device = "cpu";

        # Beam size for search (0 = auto-select based on CPU)
        beamSize = 0;

        # Optional: Add custom vocabulary for better recognition of specific terms
        # initialPrompt = ''
        #   Common commands include: turn on, turn off, set temperature, play music,
        #   stop, pause, resume. Device names: living room, bedroom, kitchen, bathroom.
        # '';
      };
    };
  };

  # Open firewall port for Wyoming Whisper
  networking.firewall.allowedTCPPorts = [10300];

  # Add to Home Assistant configuration info
  environment.etc."wyoming-whisper-info.txt" = {
    text = ''
      Wyoming Whisper STT (Speech-to-Text) Service
      =============================================

      Service is running on: tcp://ultraviolet:10300 or tcp://172.31.0.200:10300

      To use in Home Assistant:
      1. Go to Settings → Integrations → Add Integration
      2. Search for "Wyoming Protocol"
      3. Enter host: ultraviolet (or 172.31.0.200)
      4. Enter port: 10300

      Current configuration:
      - Model: base-int8 (compressed base model)
      - Language: English
      - Device: CPU

      Available models (edit this file to change):
      - tiny-int8: Fastest, least accurate (39 MB)
      - tiny: Fast, less accurate (39 MB)
      - base-int8: Good balance (compressed, 80 MB)
      - base: Good balance (145 MB)
      - small-int8: Better accuracy (compressed, 189 MB)
      - small: Better accuracy (488 MB)
      - medium: High accuracy (1.5 GB)
      - large-v3: Best accuracy (3.1 GB)
      - turbo: Faster than large-v3 with similar accuracy

      For multilingual support, change language from "en" to "auto"
    '';
  };
}
