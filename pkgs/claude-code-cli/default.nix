{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  glibc,
}:
let
  version = "2.1.56";
  gcsBase = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}";

  sources = {
    "aarch64-darwin" = fetchurl {
      url = "${gcsBase}/darwin-arm64/claude";
      hash = "sha256-x5U0IC/TPxHxER7goPoQFDGHo0Xglcst2LYYbY3Mb18=";
    };
    "x86_64-darwin" = fetchurl {
      url = "${gcsBase}/darwin-x64/claude";
      hash = "sha256-gLzN2WrxI90cx/ubbjKlbCll3DdKUIT7UoMpRgmxr/M=";
    };
    "x86_64-linux" = fetchurl {
      url = "${gcsBase}/linux-x64/claude";
      hash = "sha256-4TnXH53sTYYwg0GxbQDCREHHidAVaFI2Skx9zz8umz4=";
    };
    "aarch64-linux" = fetchurl {
      url = "${gcsBase}/linux-arm64/claude";
      hash = "sha256-VmzlxBrH7LslnUb+XVjUXAPnAyOg/z8FoN3DWNgfc6E=";
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
