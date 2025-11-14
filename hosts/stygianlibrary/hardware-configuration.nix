{modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "sd_mod"];
      kernelModules = [];
    };
    kernelModules = ["coretemp" "kvm-intel"];
    extraModulePackages = [];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/STYGIAN-SYSTEM";
      fsType = "ext4";
      options = ["noatime" "nodiratime"];
    };

    "/boot" = {
      device = "/dev/disk/by-label/STYGIAN-EFI";
      fsType = "vfat";
    };

    "/persist" = {
      device = "/dev/disk/by-label/STYGIAN-PERSIST";
      fsType = "ext4";
      neededForBoot = true;
      options = ["noatime" "nodev" "nosuid"];
    };

    "/models" = {
      device = "/dev/disk/by-label/STYGIAN-MODELS";
      fsType = "ext4";
      neededForBoot = false;
      options = ["noatime" "nodev" "nosuid"];
    };

    "/scratch" = {
      fsType = "tmpfs";
      options = ["size=64G" "mode=1777"];
    };
  };

  swapDevices = [];
}
