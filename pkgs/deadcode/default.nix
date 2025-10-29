{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "deadcode";
  version = "0.38.0";

  src = fetchFromGitHub {
    owner = "golang";
    repo = "tools";
    rev = "v${version}";
    hash = "sha256-hIPIWcCeCWYRP7pUL6NeMtykDaCn4phDdIpPDb5k5XE=";
  };

  subPackages = [ "cmd/deadcode" ];

  vendorHash = "sha256-jweDfh6rOmhnIql8Sa6yCOOjyRj2Pq7As7nPgStP204=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Reports unused declarations in Go packages";
    homepage = "https://pkg.go.dev/golang.org/x/tools/cmd/deadcode";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "deadcode";
  };
}
