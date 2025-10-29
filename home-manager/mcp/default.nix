{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  targetprocess-mcp = inputs.targetprocess-mcp.packages.${pkgs.system}.default;
  mcp-atlassian = pkgs.mcp-atlassian;
in
{
  home.packages =
    with pkgs;
    [
      targetprocess-mcp
      mcp-atlassian
    ];

  home.file =
    {
      ".mcp/.keep".text = "";
      ".mcp/bin/targetprocess-mcp".source = "${targetprocess-mcp}/bin/targetprocess-mcp";
      ".mcp/bin/mcp-atlassian".source = "${mcp-atlassian}/bin/mcp-atlassian";
      ".mcp/jira-mcp-wrapper.sh" = {
        source = ./jira-mcp-wrapper.sh;
        executable = true;
      };
    };
}
