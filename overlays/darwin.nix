final: prev: let
  inherit (prev.stdenv.hostPlatform) isDarwin;
in
  if isDarwin
  then {
    aerospace = final.callPackage ../pkgs/aerospace {};
  }
  else {}
