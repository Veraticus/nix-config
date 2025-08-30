{ lib, python3Packages, fetchFromGitHub, fetchPypi }:

with python3Packages;
let
  # Custom openapi-pydantic package (not in nixpkgs)
  openapi-pydantic = buildPythonPackage rec {
    pname = "openapi-pydantic";
    version = "0.5.1";
    src = fetchPypi {
      pname = "openapi_pydantic";
      inherit version;
      hash = "sha256-/2g1r2veekWfuT65O7krh0m3VPxuUbLxWQoZ3DAF7g0=";
    };
    pyproject = true;
    build-system = [ poetry-core ];
    propagatedBuildInputs = [ pydantic ];
    doCheck = false;
  };

  # Custom fastmcp package pinned to 2.3.5 for API compatibility
  fastmcp-2_3_5 = buildPythonPackage rec {
    pname = "fastmcp";
    version = "2.3.5";
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-CeEXI8ZYjYwTVi1esE1CsTuR6zL1PO93zIwO4SGy+Qc=";
    };
    pyproject = true;
    build-system = [ 
      hatchling 
      uv-dynamic-versioning
    ];
    propagatedBuildInputs = [ 
      exceptiongroup
      httpx
      mcp
      openapi-pydantic
      python-dotenv
      rich
      typer
      websockets
    ];
    pythonRelaxDeps = [
      "mcp"  # Allow newer mcp versions
    ];
    doCheck = false;
  };

  # Custom markdown-to-confluence package (not in nixpkgs)
  markdown-to-confluence = buildPythonPackage rec {
    pname = "markdown-to-confluence";
    version = "0.3.0";
    src = fetchPypi {
      pname = "markdown_to_confluence";
      inherit version;
      hash = "sha256-CgnDujEYw9SgLVyZsFdaihQsq11OtI6JjJFcAukE/M4=";
    };
    pyproject = true;
    build-system = [ setuptools ];
    propagatedBuildInputs = [ 
      markdown 
      lxml
      pymdown-extensions
      pyyaml
      requests
      # Type stubs (not needed at runtime but required by package metadata)
      types-pyyaml
      types-requests
      types-markdown
      types-lxml
    ];
    doCheck = false;
  };

in
buildPythonApplication rec {
  pname = "mcp-atlassian";
  version = "0.11.9";

  src = fetchFromGitHub {
    owner = "sooperset";
    repo = "mcp-atlassian";
    rev = "v${version}";
    hash = "sha256-R6edqlPgM63KRZO2rVmVWGjMRSNzIvD8P00A9vpdW9Y=";
  };
  
  pyproject = true;

  build-system = [
    hatchling
    uv-dynamic-versioning
  ];

  propagatedBuildInputs = [
    atlassian-python-api
    requests
    beautifulsoup4
    httpx
    mcp
    fastmcp-2_3_5
    python-dotenv
    markdownify
    markdown
    markdown-to-confluence
    pydantic
    trio
    click
    uvicorn
    starlette
    thefuzz
    python-dateutil
    keyring
    cachetools
  ];

  pythonRelaxDeps = [
    "fastmcp"  # We're using 2.3.5 instead of required 2.3.4
  ];
  
  # Remove type stub dependencies that are only needed for development
  pythonRemoveDeps = [
    "types-python-dateutil"
    "types-cachetools"
  ];

  # Disable checks for now as they require pytest
  doCheck = false;

  meta = with lib; {
    description = "MCP server for Atlassian products (Jira and Confluence)";
    homepage = "https://github.com/sooperset/mcp-atlassian";
    license = licenses.mit;
    maintainers = [ ];
  };
}