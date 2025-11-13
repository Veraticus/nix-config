final: prev: let
  inherit (prev.stdenv.hostPlatform) isDarwin;
in
  if isDarwin
  then {
    gtk3 = prev.gtk3.overrideAttrs (old: {
      patches = (old.patches or []) ++ [../patches/gtk3-darwin-sincos.patch];
    });

    aerospace = final.callPackage ../pkgs/aerospace {};
  }
  else {}
