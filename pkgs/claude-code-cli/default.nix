{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  glibc,
}:
let
  version = "2.1.50";
  gcsBase = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}";

  sources = {
    "aarch64-darwin" = fetchurl {
      url = "${gcsBase}/darwin-arm64/claude";
      hash = "sha256-S2wcteAkKNv2ANCPiMKPnqBmGQAcPv6/iJA2Xlt50bc=";
    };
    "x86_64-darwin" = fetchurl {
      url = "${gcsBase}/darwin-x64/claude";
      hash = "sha256-IhWBjG4qT6BJfuiKGfjYS5HwuynMQVCjCqd191uiEzw=";
    };
    "x86_64-linux" = fetchurl {
      url = "${gcsBase}/linux-x64/claude";
      hash = "sha256-dAQnORl8WKR5HB9nQUwNiVZjnsLy6TUoCHK4PUMXvng=";
    };
    "aarch64-linux" = fetchurl {
      url = "${gcsBase}/linux-arm64/claude";
      hash = "sha256-Tisj2/L5eRjV7cla4d4D0jCma5TV+jGlfMZzdC7GriI=";
    };
  };
in
stdenv.mkDerivation {
  pname = "claude-code-cli";
  inherit version;

  src = sources.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [patchelf];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp "$src" "$out/bin/claude"
    chmod +wx "$out/bin/claude"
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" "$out/bin/claude"
  '' + ''
    runHook postInstall
  '';

  meta = {
    description = "Anthropic Claude Code CLI - native binary";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [];
    platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    mainProgram = "claude";
  };
}
