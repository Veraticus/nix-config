{...}: {
  imports = [
    ../../modules/installer.nix
  ];

  autoInstaller = {
    targetHost = "ultraviolet";

    labels = {
      efi = "UV-EFI";
      root = "UV-ROOT";
      swap = "UV-SWAP";
    };

    swap = {
      enable = true;
      size = "9G";
    };

    repoClonePath = "/mnt/home/joshsymonds/nix-config";

    bannerText = ''
      ██╗   ██╗██╗  ████████╗██████╗  █████╗ ██╗   ██╗██╗ ██████╗ ██╗     ███████╗████████╗
      ██║   ██║██║  ╚══██╔══╝██╔══██╗██╔══██╗██║   ██║██║██╔═══██╗██║     ██╔════╝╚══██╔══╝
      ██║   ██║██║     ██║   ██████╔╝███████║██║   ██║██║██║   ██║██║     █████╗     ██║
      ██║   ██║██║     ██║   ██╔══██╗██╔══██║╚██╗ ██╔╝██║██║   ██║██║     ██╔══╝     ██║
      ╚██████╔╝███████╗██║   ██║  ██║██║  ██║ ╚████╔╝ ██║╚██████╔╝███████╗███████╗   ██║
       ╚═════╝ ╚══════╝╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝   ╚═╝

      Ultraviolet auto-installer. The system will install automatically on boot.
    '';
  };
}
