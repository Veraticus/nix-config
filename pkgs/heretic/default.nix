{lib, python3Packages, fetchFromGitHub, ...}:
let
  torchPackage =
    if python3Packages ? pytorchWithCuda
    then python3Packages.pytorchWithCuda
    else python3Packages.pytorch;

  pythonPackages = python3Packages.override {
    overrides = self: super: {
      torch = torchPackage;
      pytorch = torchPackage;
      pytorch-bin = torchPackage;
      pytorchWithCuda = torchPackage;
    };
  };
in
pythonPackages.buildPythonApplication rec {
  pname = "heretic";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "p-e-w";
    repo = "heretic";
    rev = "v${version}";
    hash = "sha256-04reIiD1MbNLv8IqSqVHXQorlXjLSowy8zcJ1hFBHPg=";
  };

  pyproject = true;

  nativeBuildInputs = [pythonPackages.uv-build];

  propagatedBuildInputs =
    (with pythonPackages; [
      accelerate
      datasets
      hf-transfer
      huggingface-hub
      optuna
      pydantic-settings
      questionary
      rich
      transformers
    ])
    ++ [torchPackage];

  pythonImportsCheck = ["heretic"];

  doCheck = false;

  meta = {
    description = "Fully automatic censorship removal for language models";
    homepage = "https://github.com/p-e-w/heretic";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "heretic";
  };
}
