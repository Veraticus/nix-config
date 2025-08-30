# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  myCaddy = pkgs.callPackage ./caddy { };
  starlark-lsp = pkgs.callPackage ./starlark-lsp { };
  nuclei = pkgs.callPackage ./nuclei { };
  mcp-atlassian = pkgs.callPackage ./mcp-atlassian { };
}