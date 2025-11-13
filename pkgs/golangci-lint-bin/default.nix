{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}: let
  version = "2.5.0";

  platform =
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64
    then "linux-amd64"
    else if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64
    then "linux-arm64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64
    then "darwin-amd64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64
    then "darwin-arm64"
    else throw "Unsupported platform for golangci-lint: ${stdenv.hostPlatform.system}";

  src = fetchurl {
    url = "https://github.com/golangci/golangci-lint/releases/download/v${version}/golangci-lint-${version}-${platform}.tar.gz";
    hash =
      {
        "linux-amd64" = "sha256-x3MTp34ZsGEjlixBHZlDzA0JK77Ha5VhBNGJZOJ0kC4=";
        "linux-arm64" = "sha256-SGk6mKf0VW0RFzAKriQND+SD341vNt+rpWUEYmEBpm4=";
        "darwin-amd64" = "sha256-p+aEhysAY31kLQiN3ng8G4cRYakmePzxPQer5rXDLjY=";
        "darwin-arm64" = "sha256-Czy9wqJHL2C1OOvMsbLhrl2TigUcAQWRqmjG79NwZnI=";
      }.${
        platform
      };
  };
in
  stdenv.mkDerivation {
    pname = "golangci-lint-bin";
    inherit version src;

    nativeBuildInputs = lib.optionals stdenv.isLinux [autoPatchelfHook];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      tar -xzf "$src"
      cd golangci-lint-${version}-${platform}

      install -Dm755 golangci-lint "$out/bin/golangci-lint"
      install -Dm644 README.md "$out/share/doc/golangci-lint/README.md"
      install -Dm644 LICENSE "$out/share/licenses/golangci-lint/LICENSE"
      if [ -d completions ]; then
        install -Dm644 completions/golangci-lint.bash "$out/share/bash-completion/completions/golangci-lint"
        install -Dm644 completions/golangci-lint.zsh "$out/share/zsh/site-functions/_golangci-lint"
        install -Dm644 completions/golangci-lint.fish "$out/share/fish/vendor_completions.d/golangci-lint.fish"
      fi
      runHook postInstall
    '';

    meta = {
      description = "Fast linters runner for Go (binary release)";
      homepage = "https://github.com/golangci/golangci-lint";
      license = lib.licenses.gpl3Plus;
      maintainers = with lib.maintainers; [];
      platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    };
  }
