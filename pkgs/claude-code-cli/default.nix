{ lib
, stdenv
, fetchurl
, makeWrapper
, nodejs_24
}:

stdenv.mkDerivation rec {
  pname = "claude-code-cli";
  version = "2.0.28";

  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-VyqSWl73wW+/83et6JXBpp2uTUW9JLnZpYmn4cn/dQw=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/node_modules/@anthropic-ai/claude-code"
    mkdir -p "$out/bin"

    tar -xzf "$src"
    cp -r package/* "$out/lib/node_modules/@anthropic-ai/claude-code/"

    makeWrapper ${nodejs_24}/bin/node "$out/bin/claude" \
      --add-flags "$out/lib/node_modules/@anthropic-ai/claude-code/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Anthropic Claude Code CLI for interacting with Claude from the terminal";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
    mainProgram = "claude";
  };
}
