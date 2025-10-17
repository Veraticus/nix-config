{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  # Go language configuration
  programs.go = {
    enable = true;
    package = pkgs.go_1_24;
    env = {
      GOPATH = "${config.home.homeDirectory}/go";
      GOBIN = "${config.home.homeDirectory}/go/bin";
    };
  };

  # Go development tools
  home.packages = with pkgs; [
    # Core tools
    go-tools # Official Go tools (goimports, etc.)
    gopls # Language server
    delve # Debugger

    # Formatting and refactoring
    gofumpt # Stricter gofmt
    golines # Long line formatter

    # Testing tools
    gotestsum # Better test output

    # Documentation
    # godoc is included in go-tools

    # Build tools
    goreleaser # Release automation
    go-task # Task runner (alternative to make)
  ];

  # Global golangci-lint configuration
  # This will be used by all Go projects that don't have their own .golangci.yml
  home.file.".golangci.yml".source = ./golangci.yml;

  # Environment variables for Go
  home.sessionVariables = {
    # Enable Go modules by default
    GO111MODULE = "on";

    # Set default Go proxy
    GOPROXY = "https://proxy.golang.org,direct";

    # Don't send telemetry
    GOTELEMETRY = "off";

    # Checksum database
    GOSUMDB = "sum.golang.org";
  };

  # Add Go binaries to PATH
  home.sessionPath = [
    "$HOME/go/bin"
  ];

  # Git configuration for Go
  programs.git.extraConfig = {
    # Go-specific diff patterns
    "diff.go" = {
      xfuncname = "^[ \\t]*(func|type)[ \\t]+([a-zA-Z_][a-zA-Z0-9_]*)";
    };
  };

  # Optional: Create project template directory structure
  home.file.".go-templates/.keep".text = "";

  # Activation script to ensure golangci-lint is installed
  home.activation.installGolangciLint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Installing/updating golangci-lint..."
    export PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.curl}/bin/curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b $HOME/go/bin
  '';

  # Activation script to ensure deadcode is installed
  home.activation.installDeadcode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Installing/updating deadcode..."
    export PATH="${pkgs.go_1_24}/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.go_1_24}/bin/go install golang.org/x/tools/cmd/deadcode@latest
  '';

  # Activation script to ensure ko is installed
  home.activation.installKo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Installing/updating ko..."
    export PATH="${pkgs.go_1_24}/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.go_1_24}/bin/go install github.com/google/ko@latest
  '';

  # Helpful aliases for Go development
  home.shellAliases = {
    # Testing shortcuts
    got = "go test ./...";
    gotv = "go test -v ./...";
    gotr = "go test -race ./...";
    gotc = "go test -cover ./...";

    # Linting shortcuts
    gol = "golangci-lint run";
    golf = "golangci-lint run --fix";
    golu = "curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b $(go env GOPATH)/bin";

    # Module management
    gomu = "go mod download && go mod tidy";
    gomv = "go mod vendor";

    # Quick build/run
    gob = "go build";
    gor = "go run";

    # Format all Go files
    gofmtall = "gofumpt -l -w .";
  };
}
