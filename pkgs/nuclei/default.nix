{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "nuclei";
  version = "3.3.7";

  src = fetchFromGitHub {
    owner = "projectdiscovery";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-cvbxLEXPvJgAWHAMmHXPyHtBkYOOXj9xz1zfrm8oLG4=";
  };

  vendorHash = "sha256-2zrT/oQc+cgnxN7Y8S5Lx+Aapf10aInjUtRW73N0O3o=";

  subPackages = [
    "cmd/nuclei"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/projectdiscovery/nuclei/v3/pkg/types.VERSION=${version}"
  ];

  meta = with lib; {
    description = "Fast and customizable vulnerability scanner based on simple YAML based DSL";
    homepage = "https://nuclei.projectdiscovery.io/";
    license = licenses.mit;
    maintainers = with maintainers; [];
    mainProgram = "nuclei";
  };
}
