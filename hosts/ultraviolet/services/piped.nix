_: {
  systemd.tmpfiles.rules = [
    "d /etc/piped 0755 root root -"
  ];

  environment.etc."piped/config.properties" = {
    mode = "0640";
    text = ''
      PORT: 8080
      HTTP_WORKERS: 2
      PROXY_PART: https://piped-proxy.home.husbuddies.gay
      API_URL: https://piped-api.home.husbuddies.gay
      FRONTEND_URL: https://piped.home.husbuddies.gay
      COMPROMISED_PASSWORD_CHECK: false
      DISABLE_REGISTRATION:true
      FEED_RETENTION: 30
      SPONSORBLOCK_SERVERS:https://sponsor.ajay.app,https://sponsorblock.kavin.rocks
      RYD_PROXY_URL:https://ryd-proxy.kavin.rocks
      BG_HELPER_URL:http://piped-bg-helper:3000
      hibernate.connection.url:jdbc:postgresql://host.containers.internal:5432/piped
      hibernate.connection.driver_class:org.postgresql.Driver
      hibernate.dialect:org.hibernate.dialect.PostgreSQLDialect
      hibernate.connection.username:piped
      hibernate.connection.password:
    '';
  };

  virtualisation.oci-containers.containers = {
    piped-bg-helper = {
      image = "docker.io/1337kavin/bg-helper-server:latest";
      autoRemoveOnStop = false;
    };

    piped-proxy = {
      image = "docker.io/1337kavin/piped-proxy:latest";
      ports = ["127.0.0.1:8088:8080"];
      autoRemoveOnStop = false;
    };

    piped-backend = {
      image = "docker.io/1337kavin/piped:latest";
      ports = ["127.0.0.1:8087:8080"];
      volumes = ["/etc/piped/config.properties:/app/config.properties:ro"];
      dependsOn = ["piped-bg-helper"];
      extraOptions = ["--add-host=host.containers.internal:10.88.0.1"];
      autoRemoveOnStop = false;
    };

    piped-frontend = {
      image = "docker.io/1337kavin/piped-frontend:latest";
      environment = {
        BACKEND_HOSTNAME = "piped-api.home.husbuddies.gay";
        HTTP_MODE = "https";
      };
      ports = ["127.0.0.1:8086:80"];
      dependsOn = ["piped-backend" "piped-proxy"];
      autoRemoveOnStop = false;
      capabilities.NET_BIND_SERVICE = true;
    };
  };

  services.caddy.virtualHosts = {
    "piped.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* 127.0.0.1:8086
      import cloudflare
    '';
    "piped-api.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* 127.0.0.1:8087
      import cloudflare
    '';
    "piped-proxy.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* 127.0.0.1:8088 {
        header_up Host {http.request.header.Host}
      }
      import cloudflare
    '';
  };
}
