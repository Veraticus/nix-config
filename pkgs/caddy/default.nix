{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nixosTests,
  caddy,
  testers,
  installShellFiles,
}: let
  dist = fetchFromGitHub {
    owner = "Veraticus";
    repo = "caddy-dist";
    rev = "v2.7.6";
    hash = "sha256-5DRkWQmH2s5QkZL/YPqGfy343B6W5SRd8z1zMs675gs=";
  };
in
  buildGoModule {
    pname = "caddy";
    version = "2.7.5";

    src = fetchFromGitHub {
      owner = "Veraticus";
      repo = "caddy";
      rev = "v2.7.5";
      hash = "sha256-b3M/xO3HnDmTUm+cVrAkkdHXnJv3858G78v6JDaF+SA=";
    };

    vendorHash = "sha256-nFL6tRqHzXkDZITCiF2RTs3eGaJMYbXkTr8etPSWy/M=";

    subPackages = ["cmd/caddy"];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/caddyserver/caddy/v2.CustomVersion=v2.7.5"
    ];

    nativeBuildInputs = [installShellFiles];

    postInstall = ''
      install -Dm644 ${dist}/init/caddy.service ${dist}/init/caddy-api.service -t $out/lib/systemd/system

      substituteInPlace $out/lib/systemd/system/caddy.service --replace "/usr/bin/caddy" "$out/bin/caddy"
      substituteInPlace $out/lib/systemd/system/caddy-api.service --replace "/usr/bin/caddy" "$out/bin/caddy"

      $out/bin/caddy manpage --directory manpages
      installManPage manpages/*

      installShellCompletion --cmd caddy \
        --bash <($out/bin/caddy completion bash) \
        --fish <($out/bin/caddy completion fish) \
        --zsh <($out/bin/caddy completion zsh)
    '';

    passthru.tests = {
      inherit (nixosTests) caddy;
      version = testers.testVersion {
        command = "${caddy}/bin/caddy version";
        package = caddy;
      };
    };

    meta = with lib; {
      homepage = "https://caddyserver.com";
      description = "Fast and extensible multi-platform HTTP/1-2-3 web server with automatic HTTPS";
      license = licenses.asl20;
      maintainers = with maintainers; [Br1ght0ne emilylange techknowlogick];
    };
  }
