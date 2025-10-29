{ lib, stdenv, fetchurl, unzip }:

let
  version = "2.14.1";

  sources = {
    "x86_64-linux" = {
      url = "https://github.com/coder/coder/releases/download/v${version}/coder_${version}_linux_amd64.tar.gz";
      hash = "sha256-zOMcngzhG6SxN/Hjamf5g0Cb/nhrD3NcVKC8MdL2L80=";
      unpackCmd = "tar -xzf \"$src\"";
    };
    "aarch64-linux" = {
      url = "https://github.com/coder/coder/releases/download/v${version}/coder_${version}_linux_arm64.tar.gz";
      hash = "sha256-RsQ3sv5t+o6gObdG81hZ8dHng39qjlynENH30oAhZqM=";
      unpackCmd = "tar -xzf \"$src\"";
    };
    "x86_64-darwin" = {
      url = "https://github.com/coder/coder/releases/download/v${version}/coder_${version}_darwin_amd64.zip";
      hash = "sha256-FzFrE3moll8D0of0Chs47XI9baAjFDzpcPJdpwteMpE=";
      unpackCmd = "unzip -q \"$src\"";
    };
    "aarch64-darwin" = {
      url = "https://github.com/coder/coder/releases/download/v${version}/coder_${version}_darwin_arm64.zip";
      hash = "sha256-MPIm/d6fOe6DjVIewDeoxMs2OKz9urWgKMW6vmM9RGs=";
      unpackCmd = "unzip -q \"$src\"";
    };
  };

  info = sources.${stdenv.hostPlatform.system}
    or (throw "coder-cli: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "coder";
  inherit version;

  src = fetchurl {
    inherit (info) url hash;
  };

  nativeBuildInputs = lib.optionals (lib.hasSuffix ".zip" info.url) [ unzip ];

  unpackPhase = info.unpackCmd;

  installPhase = ''
    runHook preInstall
    install -Dm755 coder "$out/bin/coder"
    install -Dm644 LICENSE "$out/share/doc/coder/LICENSE"
    install -Dm644 LICENSE.enterprise "$out/share/doc/coder/LICENSE.enterprise"
    install -Dm644 README.md "$out/share/doc/coder/README.md"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Coder CLI ${version}";
    homepage = "https://coder.com";
    license = licenses.agpl3Plus;
    maintainers = [ ];
    platforms = builtins.attrNames sources;
  };
}
