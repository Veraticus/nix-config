/*
  Compatibility shim for agenix CLI.

  Run commands like:
    agenix -e secrets/coder-env.age

  The attrset lives in ./secrets/secrets.nix; keep logic there.
*/
import ./secrets/secrets.nix
