{pkgs, ...}: {
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    group = "users";
    openFirewall = true;
    user = "jellyfin";
  };

  users.users.jellyfin.extraGroups = ["video" "render"];

  services.caddy.virtualHosts."jellyfin.home.husbuddies.gay".extraConfig = ''
    reverse_proxy /* localhost:8096
    import cloudflare
  '';
}
