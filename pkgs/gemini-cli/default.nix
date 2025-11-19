{
  pkgs,
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
  python3,
  xcbuild,
  pkg-config,
  libsecret,
}:
buildNpmPackage rec {
  pname = "gemini-cli";
  version = "0.18.0-nightly.20251118.7cc5234b9";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    rev = "v${version}";
    hash = "sha256-pQ8o9MHpJfb+7LKZ28rvcL7KF4IJKeDw1Uv0IiaXANo=";
  };

  sourceRoot = "source";

  # Hash for the dependencies. Set to zeroes to force re-calculation.
  npmDepsHash = "sha256-q8LMBpKL5GEgObqUl8U2wtfdraYWorwCFZylrekwGVM=";

  nodejs = nodejs_22;

  # Needed for native modules
  nativeBuildInputs = [ python3 pkg-config xcbuild ];
  
  buildInputs = [ libsecret ];
  
  env = {
    NIX_CFLAGS_COMPILE = "-w -Wno-error";
  };
  npmFlags = [ ];
  
  makeCacheWritable = true;

  buildPhase = ''
    runHook preBuild
    npm run generate
    npm run --workspace @google/gemini-cli build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/lib/node_modules/@google/gemini-cli
    mkdir -p $out/bin
    
    # Copy everything (including node_modules which now has deps)
    cp -r . $out/lib/node_modules/@google/gemini-cli/
    
    # Create a wrapper script that runs the CLI with the bundled Node interpreter
    cat > $out/bin/gemini <<EOF
#!/bin/sh
HOOK_SCRIPT="\$HOME/.gemini/hooks/ntfy-notifier.sh"

# Run the Gemini CLI
${nodejs_22}/bin/node "$out/lib/node_modules/@google/gemini-cli/packages/cli/dist/index.js" "\$@"
EXIT_CODE=\$?

# Run post-execution hook if it exists and executable
if [ -x "\$HOOK_SCRIPT" ]; then
  # Pass a simulated JSON event to the hook
  echo '{"event":"Stop","tool":"gemini","tool_input":{}}' | "\$HOOK_SCRIPT" >/dev/null 2>&1 &
  # Detach background process so we don't wait for it
  disown
fi

exit \$EXIT_CODE
EOF
    
    chmod +x $out/bin/gemini
      
    runHook postInstall
  '';

  meta = {
    description = "Gemini CLI - An open-source AI agent for your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
}
