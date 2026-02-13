{pkgs, ...}: {
  imports = [
    ../../modules/installer.nix
  ];

  autoInstaller = {
    targetHost = "stygianlibrary";
    prebuilt = true;

    labels = {
      efi = "STYGIAN-EFI";
      root = "STYGIAN-ROOT";
      luks = "STYGIAN-LUKS";
    };

    luks = {
      enable = true;
      mapperName = "stygiancrypt";
    };

    extraMountDirs = ["persist" "models"];

    extraPostMountCommands = [
      "chmod 755 /mnt/persist"
      "chmod 755 /mnt/models"
      "install -d -m 0755 -o root -g root /mnt/persist/ollama"
    ];

    repoClonePath = "/mnt/persist/nix-config";

    extraInitrdKernelModules = ["thunderbolt"];

    extraBootCommands = ''
      for dev in /sys/bus/thunderbolt/devices/*; do
        if [ -w "$dev/authorized" ]; then
          echo 1 >"$dev/authorized"
        fi
      done
    '';

    extraPackages = [pkgs.bolt];

    bannerText = ''
      ███████╗████████╗██╗   ██╗ ██████╗ ██╗ █████╗ ███╗   ██╗██╗      ██╗██╗   ██╗
      ██╔════╝╚══██╔══╝██║   ██║██╔════╝ ██║██╔══██╗████╗  ██║██║  ██╗██╔╝██║   ██║
      ███████╗   ██║   ██║   ██║██║  ███╗██║███████║██╔██╗ ██║╚██╗ ██╔╝██║ ██║   ██║
      ╚════██║   ██║   ██║   ██║██║   ██║██║██╔══██║██║╚██╗██║ ╚████╔╝ ██║ ██║   ██║
      ███████║   ██║   ╚██████╔╝╚██████╔╝██║██║  ██║██║ ╚████║  ╚██╔╝  ██║ ╚██████╔╝
      ╚══════╝   ╚═╝    ╚═════╝  ╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═════╝

      Stygianlibrary field kit. Use flash-stygianlibrary.sh to image Thunderbolt media.
    '';
  };

  services.hardware.bolt.enable = true;
}
