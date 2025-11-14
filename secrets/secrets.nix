# Define which encrypted files belong to which recipients.
# Update this attrset when creating new secrets with `agenix -e`.
let
  keys = import ./keys.nix;
in {
  # Shared secrets
  "secrets/shared/coder-db-password.age".publicKeys = keys.vermissian;
  "secrets/shared/coder-env.age".publicKeys = keys.vermissian;

  # Host-specific secrets
  "secrets/hosts/ultraviolet/cloudflare-api-token.age".publicKeys = keys.ultraviolet;
  "secrets/hosts/ultraviolet/cloudflared-token.age".publicKeys = keys.ultraviolet;
  "secrets/hosts/ultraviolet/redlib-collections.age".publicKeys = keys.ultraviolet;
  "secrets/hosts/vermissian/cloudflared-token.age".publicKeys = keys.vermissian;
  "secrets/hosts/vermissian/coder-ghcr-cache-auth.age".publicKeys = keys.vermissian;
}
