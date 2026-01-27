{
  lib,
  python3Packages,
  fetchFromGitHub,
  ...
}:
  python3Packages.buildPythonApplication rec {
    pname = "heretic";
    version = "1.0.1";

    src = fetchFromGitHub {
      owner = "p-e-w";
      repo = "heretic";
      rev = "v${version}";
      hash = "sha256-04reIiD1MbNLv8IqSqVHXQorlXjLSowy8zcJ1hFBHPg=";
    };

    pyproject = true;

    nativeBuildInputs = [python3Packages.uv-build];

    propagatedBuildInputs = with python3Packages; [
      accelerate
      datasets
      hf-transfer
      huggingface-hub
      optuna
      pydantic-settings
      questionary
      rich
      torch
      transformers
    ];

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
