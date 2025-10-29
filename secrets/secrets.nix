# Define which encrypted files belong to which recipients.
# Update this attrset when creating new secrets with `agenix -e`.
#
# Example:
# {
#   "secrets/coder-db-password.age".publicKeys = import ./keys.nix."vermissian";
# }
let
  keys = import ./keys.nix;
in {
  "secrets/coder-db-password.age".publicKeys = keys.vermissian;
  "secrets/coder-env.age".publicKeys = keys.vermissian;
}
