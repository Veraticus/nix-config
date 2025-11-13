{
  config,
  lib,
  ...
}: {
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
      expose-group-apps = false;
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
      wvous-br-corner = 1;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
    };

    finder = {
      CreateDesktop = false;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      NewWindowTarget = "Desktop";
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
    };

    spaces = {
      spans-displays = true;
    };
  };
}
