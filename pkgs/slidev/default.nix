{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  playwright-test,
  playwright-driver,
}:
let
  pnpm = pnpm_10;
in
stdenv.mkDerivation (finalAttrs: rec {
  pname = "slidev";
  version = "52.6.0";

  src = fetchFromGitHub {
    owner = "slidevjs";
    repo = "slidev";
    tag = "v${version}";
    hash = "sha256-FbFpPCEdIB4Cr/rOMEBLDPdfSRyEivf6FU/V7UpgRDw=";
  };

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-BOhMyRJgdYH9+lRquxbyBbrUsbjBltzgB7wnDn05EUU=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm.configHook
  ];

  propagatedBuildInputs = [
    pnpm
    playwright-test
    playwright-driver.passthru.browsers
  ];

  buildPhase = ''
    runHook preBuild

    pnpm install --frozen-lockfile --offline

    pnpm --filter "@slidev/cli" \
      --filter "@slidev/parser" \
      --filter "@slidev/types" \
      --filter "@slidev/client" \
      --filter "@slidev/theme-default" \
      --filter "@slidev/shared" run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/lib/node_modules
    cp -r node_modules/. $out/lib/node_modules/

    rm -rf $out/lib/node_modules/@slidev/cli
    mkdir -p $out/lib/node_modules/@slidev/cli
    cp -r packages/slidev/dist $out/lib/node_modules/@slidev/cli/
    cp packages/slidev/package.json $out/lib/node_modules/@slidev/cli/

    rm -rf $out/lib/node_modules/@slidev/parser
    mkdir -p $out/lib/node_modules/@slidev/parser
    cp -r packages/parser/dist $out/lib/node_modules/@slidev/parser/
    cp packages/parser/package.json $out/lib/node_modules/@slidev/parser/

    rm -rf $out/lib/node_modules/@slidev/types
    mkdir -p $out/lib/node_modules/@slidev/types
    cp -r packages/types/dist $out/lib/node_modules/@slidev/types/
    cp packages/types/package.json $out/lib/node_modules/@slidev/types/

    rm -rf $out/lib/node_modules/@slidev/client
    mkdir -p $out/lib/node_modules/@slidev/client
    cp -r packages/client/* $out/lib/node_modules/@slidev/client/
    if [ -d "packages/client/dist" ]; then
      cp -r packages/client/dist $out/lib/node_modules/@slidev/client/dist
    fi
    if [ -d "packages/client/.generated" ]; then
      cp -r packages/client/.generated $out/lib/node_modules/@slidev/client/
    fi

    if [ ! -d "$out/lib/node_modules/@slidev/theme-default" ]; then
      if [ -d "node_modules/@slidev/theme-default" ]; then
        cp -r node_modules/@slidev/theme-default $out/lib/node_modules/
      elif [ -d "packages/theme-default/dist" ]; then
        mkdir -p $out/lib/node_modules/@slidev/theme-default/dist
        cp -r packages/theme-default/dist/* $out/lib/node_modules/@slidev/theme-default/dist/
        cp packages/theme-default/package.json $out/lib/node_modules/@slidev/theme-default/package.json
      else
        echo "Warning: slidev theme-default not found during install" >&2
      fi
    fi

    cat > $out/bin/slidev <<'EOF'
#!/bin/sh
set -euo pipefail

LIBNODE="@libnode@"
export PATH="@pnpm@/bin:$PATH"
if [ -n "''${NODE_PATH:-}" ]; then
  export NODE_PATH="$LIBNODE:$NODE_PATH"
else
  export NODE_PATH="$LIBNODE"
fi

PLAYWRIGHT_TMPDIR=$(mktemp -d)
trap 'rm -rf "$PLAYWRIGHT_TMPDIR"' EXIT
if ls "@playwrightBrowsers@" >/dev/null 2>&1; then
  cp -RL "@playwrightBrowsers@"/* "$PLAYWRIGHT_TMPDIR/"
fi
for browser in "@playwrightBrowsers@"/chromium_headless_shell-*; do
  if [ -e "$browser" ]; then
    ln -sf "$browser" "$PLAYWRIGHT_TMPDIR/chromium_headless_shell-1194"
    break
  fi
done
export PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_TMPDIR"
exec "@nodejs@/bin/node" "@slidevCli@/dist/cli.js" "$@"
EOF
    substituteInPlace $out/bin/slidev \
      --subst-var-by pnpm ${pnpm} \
      --subst-var-by nodejs ${nodejs} \
      --subst-var-by playwrightBrowsers ${playwright-driver.passthru.browsers} \
      --subst-var-by libnode "$out/lib/node_modules" \
      --subst-var-by slidevCli "$out/lib/node_modules/@slidev/cli"
    chmod +x $out/bin/slidev

    runHook postInstall
  '';

  dontFixup = true;

  meta = with lib; {
    description = "Presentation slides for developers";
    homepage = "https://sli.dev/";
    license = licenses.mit;
    maintainers = with maintainers; [ taranarmo ];
    mainProgram = "slidev";
    platforms = platforms.unix;
  };
})
