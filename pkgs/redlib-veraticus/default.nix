{
  pkgs,
  crane,
  redlibSrc,
  redlibRev ? "dirty",
  rustOverlay,
  lib ? pkgs.lib,
}: let
  pkgsWithRust = pkgs.extend (import rustOverlay);
  rustToolchain = pkgsWithRust.rust-bin.stable."1.83.0".default.override {
    targets = ["x86_64-unknown-linux-musl"];
  };
  craneLib = (crane.mkLib pkgsWithRust).overrideToolchain rustToolchain;
  cleanedSrc = lib.cleanSourceWith {
    src = craneLib.path redlibSrc;
    filter = path: type:
      (lib.hasInfix "/templates/" path)
      || (lib.hasInfix "/static/" path)
      || (craneLib.filterCargoSources path type);
  };
in
  craneLib.buildPackage {
    pname = "redlib-veraticus";
    version = builtins.substring 0 8 redlibRev;

    src = cleanedSrc;
    strictDeps = true;
    doCheck = false;

    CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
    CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";

    meta = {
      description = "Private Reddit front-end (Veraticus fork)";
      homepage = "https://github.com/Veraticus/redlib";
      license = lib.licenses.agpl3Only;
      mainProgram = "redlib";
      platforms = ["x86_64-linux"];
    };
  }
