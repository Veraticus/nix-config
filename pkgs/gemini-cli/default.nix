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
SHOULD_NOTIFY=0

# Detect piped/stdin usage (common for headless prompts)
if [ ! -t 0 ]; then
  SHOULD_NOTIFY=1
fi

# Detect explicit prompt flags (-p/--prompt) or positional prompts
EXPECT_PROMPT_VALUE=0
for arg in "\$@"; do
  if [ "\$EXPECT_PROMPT_VALUE" -eq 1 ]; then
    EXPECT_PROMPT_VALUE=0
    SHOULD_NOTIFY=1
    continue
  fi
  case "\$arg" in
    -p|--prompt)
      EXPECT_PROMPT_VALUE=1
      ;;
    --prompt=*)
      SHOULD_NOTIFY=1
      ;;
    mcp|extensions)
      # Subcommands shouldn't trigger notifications by themselves
      break
      ;;
    --*)
      ;;
    -*)
      ;;
    *)
      SHOULD_NOTIFY=1
      break
      ;;
  esac
done

${nodejs_22}/bin/node "$out/lib/node_modules/@google/gemini-cli/packages/cli/dist/index.js" "\$@"
EXIT_CODE=\$?

if [ "\$SHOULD_NOTIFY" -eq 1 ] && [ -x "\$HOOK_SCRIPT" ]; then
  printf '%s\n' '{"event":"Stop","tool":"gemini","tool_input":{}}' | "\$HOOK_SCRIPT" >/dev/null 2>&1 &
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
