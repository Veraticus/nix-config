{ config, lib, ... }:

let
  inherit (lib) attrByPath optionalAttrs;
  primaryUser = attrByPath [ "system" "primaryUser" ] null config;
  primaryHome =
    if primaryUser == null then null
    else
      let
        userHome = attrByPath [ "users" "users" primaryUser "home" ] null config;
      in if userHome != null then userHome else "/Users/${primaryUser}";
  desktopTarget =
    if primaryHome == null then null
    else "file://${primaryHome}/Desktop/";
in {
  system.defaults = {
    NSGlobalDomain = {
      AppleFontSmoothing = 1;
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Automatic";
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      _HIHideMenuBar = false;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      expose-animation-duration = 0.1;
      expose-group-by-app = false;
      largesize = 128;
      launchanim = false;
      mineffect = "scale";
      minimize-to-application = true;
      mru-spaces = false;
      orientation = "bottom";
      show-process-indicators = true;
      show-recents = false;
      tilesize = 36;
      wvous-bl-corner = 1;
      wvous-bl-modifier = 0;
      wvous-br-corner = 1;
      wvous-br-modifier = 0;
      wvous-tl-corner = 1;
      wvous-tl-modifier = 0;
      wvous-tr-corner = 1;
      wvous-tr-modifier = 0;
    };

    finder =
      {
        CreateDesktop = false;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        NewWindowTarget = "PfDe";
        ShowPathbar = true;
        ShowStatusBar = true;
        WarnOnEmptyTrash = false;
        _FXShowPosixPathInTitle = true;
      }
      // optionalAttrs (desktopTarget != null) {
        NewWindowTargetPath = desktopTarget;
      };

    spaces = {
      spans-displays = true;
    };
  };
}
