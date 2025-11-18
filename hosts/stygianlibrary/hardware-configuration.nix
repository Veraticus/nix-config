{modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "sd_mod"];
      kernelModules = [];
      luks.devices.stygian = {
        device = "/dev/disk/by-partlabel/STYGIAN-LUKS";
        allowDiscards = true;
      };
    };
    kernelModules = ["coretemp" "kvm-intel"];
    extraModulePackages = [];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/STYGIAN-ROOT";
      fsType = "ext4";
      options = ["noatime" "nodiratime"];
    };

    "/boot" = {
      device = "/dev/disk/by-label/STYGIAN-EFI";
      fsType = "vfat";
    };

    "/scratch" = {
      fsType = "tmpfs";
      options = ["size=64G" "mode=1777"];
    };
  };

  swapDevices = [];
}
