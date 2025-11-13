{
  config,
  pkgs,
  ...
}: {
  xdg.configFile."media" = {
    source = pkgs.media.conf;
    recursive = true;
  };

  systemd.services.media = {
    script = ''
      ${pkgs.docker-compose.bin}/docker-compose -f ${pkgs.media.src}/docker-compose.yml --env-file ${config.xdg.configHome}/media/.env
    '';
    workingDirectory = pkgs.media.src;
    wantedBy = ["multi-user.target"];
    after = ["docker.service" "docker.socket"];
  };

  home.packages = [docker-compose];
}
