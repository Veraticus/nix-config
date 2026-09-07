{
  pkgs,
  config,
  ...
}: let
  inherit (config.networking) hostName;
  ageDir = "/etc/age";
  hostKey = "/etc/ssh/ssh_host_ed25519_key";
  hostAgeKey = "${ageDir}/${hostName}.agekey";
  keysFile = "${ageDir}/keys.txt";
  recipientsFile = "${ageDir}/recipients.txt";
in {
  age.identityPaths = [hostAgeKey];

  # No `set -e` here: activation snippets are concatenated into ONE bash
  # script, so a `set -euo pipefail` in this (early) snippet turns every
  # later snippet's failure into a hard exit before /run/current-system is
  # linked. That is how a single failed agenix decrypt or impermanence
  # bind aborted nixos-install for vermissian (Sep 2026). NixOS already
  # traps errors per snippet and reports them; rely on that.
  system.activationScripts.ageHostKey = ''
    mkdir -p ${ageDir}
    chmod 700 ${ageDir}

    if [ ! -f ${hostKey} ]; then
      echo "WARNING: ${hostKey} not found; skipping age identity generation"
    else
      SSH_TO_AGE=${pkgs.ssh-to-age}/bin/ssh-to-age

      if [ ! -f ${hostAgeKey} ]; then
        echo "Generating age identity from ${hostKey}"
        if $SSH_TO_AGE --private-key < ${hostKey} > ${hostAgeKey}.tmp; then
          mv ${hostAgeKey}.tmp ${hostAgeKey}
          chmod 600 ${hostAgeKey}
        else
          rm -f ${hostAgeKey}.tmp
          echo "ERROR: ssh-to-age failed; ${hostAgeKey} not generated" >&2
          false
        fi
      fi

      # Warn if SSH host key and agekey have diverged (e.g. SSH key was
      # regenerated after the agekey was created). agenix uses the agekey,
      # NOT the SSH key — so keys.nix must reference the agekey's public
      # key. This drift is harmless but causes confusion when re-keying.
      SSH_PUB=$($SSH_TO_AGE < ${hostKey}.pub 2>/dev/null || true)
      AGE_PUB=$(${pkgs.age}/bin/age-keygen -y ${hostAgeKey} 2>/dev/null || true)
      if [ -n "$SSH_PUB" ] && [ -n "$AGE_PUB" ] && [ "$SSH_PUB" != "$AGE_PUB" ]; then
        echo "WARNING: SSH host key and age identity have diverged!"
        echo "  agekey (/etc/age): $AGE_PUB  <-- agenix uses this, keys.nix must match"
        echo "  SSH host key:      $SSH_PUB  <-- NOT used by agenix"
        echo "  To sync: delete ${hostAgeKey} and rebuild (then re-key all secrets)"
      fi

      cat ${hostAgeKey} > ${keysFile}
      chmod 600 ${keysFile}

      if $SSH_TO_AGE < ${hostKey}.pub > ${recipientsFile}.tmp; then
        mv ${recipientsFile}.tmp ${recipientsFile}
        chmod 644 ${recipientsFile}
      else
        rm -f ${recipientsFile}.tmp
      fi
    fi
  '';
}
