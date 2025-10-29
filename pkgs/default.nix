# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { }, inputs ? null, outputs ? null }:
let
  egoenginePkgs =
    if inputs == null then
      { }
    else
      import ./egoengine {
        inherit pkgs inputs;
      };
in
{
  myCaddy = pkgs.callPackage ./caddy { };
  starlark-lsp = pkgs.callPackage ./starlark-lsp { };
  nuclei = pkgs.callPackage ./nuclei { };
  mcp-atlassian = pkgs.callPackage ./mcp-atlassian { };
  claudeCodeCli = pkgs.callPackage ./claude-code-cli { };
  deadcode = pkgs.callPackage ./deadcode { };
  golangciLintBin = pkgs.callPackage ./golangci-lint-bin { };
}
// egoenginePkgs
