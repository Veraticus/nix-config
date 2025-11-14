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

  system.activationScripts.ageHostKey = ''
    set -euo pipefail

    mkdir -p ${ageDir}
    chmod 700 ${ageDir}

    if [ ! -f ${hostKey} ]; then
      echo "WARNING: ${hostKey} not found; skipping age identity generation"
    else
      SSH_TO_AGE=${pkgs.ssh-to-age}/bin/ssh-to-age

      if [ ! -f ${hostAgeKey} ]; then
        echo "Generating age identity from ${hostKey}"
        $SSH_TO_AGE --private-key < ${hostKey} > ${hostAgeKey}.tmp
        mv ${hostAgeKey}.tmp ${hostAgeKey}
        chmod 600 ${hostAgeKey}
      fi

      cat ${hostAgeKey} > ${keysFile}
      chmod 600 ${keysFile}

      $SSH_TO_AGE < ${hostKey}.pub > ${recipientsFile}.tmp
      mv ${recipientsFile}.tmp ${recipientsFile}
      chmod 644 ${recipientsFile}
    fi
  '';
}
