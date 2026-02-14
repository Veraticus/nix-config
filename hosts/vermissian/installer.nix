{...}: {
  imports = [
    ../../modules/installer.nix
  ];

  autoInstaller = {
    targetHost = "vermissian";

    labels = {
      efi = "VM-EFI";
      root = "VM-ROOT";
      swap = "VM-SWAP";
    };

    swap = {
      enable = true;
      size = "32G";
    };

    repoClonePath = "/mnt/home/joshsymonds/nix-config";

    bannerText = ''
      ██╗   ██╗███████╗██████╗ ███╗   ███╗██╗███████╗███████╗██╗ █████╗ ███╗   ██╗
      ██║   ██║██╔════╝██╔══██╗████╗ ████║██║██╔════╝██╔════╝██║██╔══██╗████╗  ██║
      ██║   ██║█████╗  ██████╔╝██╔████╔██║██║███████╗███████╗██║███████║██╔██╗ ██║
      ╚██╗ ██╔╝██╔══╝  ██╔══██╗██║╚██╔╝██║██║╚════██║╚════██║██║██╔══██║██║╚██╗██║
       ╚████╔╝ ███████╗██║  ██║██║ ╚═╝ ██║██║███████║███████║██║██║  ██║██║ ╚████║
        ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

      Vermissian auto-installer. The system will install automatically on boot.
    '';
  };
}
