{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs_22,
}:
stdenv.mkDerivation rec {
  pname = "gemini-cli";
  version = "0.18.0-nightly.20251118.7cc5234b9";

  src = fetchurl {
    url = "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-${version}.tgz";
    hash = "sha512-EgO0IC2+eAaY93XFxcVYLyxuS9BM8uqwgWriT1YJ2OKtojiFRYDTi9auLQqUcw18ah5LLo6645TRyXmjtqAn8w==";
  };

  nativeBuildInputs = [makeWrapper];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/node_modules/@google/gemini-cli"
    mkdir -p "$out/bin"

    tar -xzf "$src"
    # npm tarballs usually have a 'package' directory at the root
    cp -r package/* "$out/lib/node_modules/@google/gemini-cli/"

    makeWrapper ${nodejs_22}/bin/node "$out/bin/gemini" \
      --add-flags "$out/lib/node_modules/@google/gemini-cli/bundle/gemini.js"

    runHook postInstall
  '';

  meta = {
    description = "Gemini CLI - An open-source AI agent for your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.apache20;
    maintainers = with lib.maintainers; [];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
}
