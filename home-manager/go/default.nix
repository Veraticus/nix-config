{ lib, config, pkgs, ... }:
let
  cfg = config.programs.go.enable or false;
in
{
  config = lib.mkIf cfg {
    programs.go = {
      package = pkgs.go_1_24;
      env = {
        GOPATH = "${config.home.homeDirectory}/go";
        GOBIN = "${config.home.homeDirectory}/go/bin";
      };
    };

    home.packages =
      (with pkgs; [
        go-tools
        gopls
        delve
        gofumpt
        golines
        gotestsum
        goreleaser
        go-task
        ko
      ])
      ++ [
        pkgs.golangciLintBin
        pkgs.deadcode
      ];

    home.sessionVariables = {
      GO111MODULE = lib.mkDefault "on";
      GOPROXY = lib.mkDefault "https://proxy.golang.org,direct";
      GOTELEMETRY = lib.mkDefault "off";
      GOSUMDB = lib.mkDefault "sum.golang.org";
    };

    home.sessionPath = lib.mkAfter [ "$HOME/go/bin" ];

    programs.git.extraConfig."diff.go" = {
      xfuncname = "^[ \t]*(func|type)[ \t]+([a-zA-Z_][a-zA-Z0-9_]*)";
    };

    home.file.".go-templates/.keep".text = "";

    home.shellAliases = {
      got = "go test ./...";
      gotv = "go test -v ./...";
      gotr = "go test -race ./...";
      gotc = "go test -cover ./...";
      gol = "golangci-lint run";
      golf = "golangci-lint run --fix";
      golu = "echo 'golangci-lint is managed by Nix (pkgs.golangciLintBin); bump pkgs/golangci-lint-bin to update.'";
      gomu = "go mod download && go mod tidy";
      gomv = "go mod vendor";
      gob = "go build";
      gor = "go run";
      gofmtall = "gofumpt -l -w .";
    };
  };
}
