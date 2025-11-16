{lib, python3Packages, ...}:
let
  torch =
    if python3Packages ? pytorchWithCuda
    then python3Packages.pytorchWithCuda
    else python3Packages.pytorch;
in
python3Packages.buildPythonApplication rec {
  pname = "heretic";
  version = "1.0.1";

  src = ../../reference/heretic;

  pyproject = true;

  nativeBuildInputs = [python3Packages.uv-build];

  propagatedBuildInputs =
    (with python3Packages; [
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
    ++ [torch];

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
