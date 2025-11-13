_: {
  virtualisation.oci-containers.containers.flaresolverr = {
    image = "flaresolverr/flaresolverr:v3.3.18";
    ports = ["8191:8191"];
    extraOptions = ["--network=host"];
  };
}
