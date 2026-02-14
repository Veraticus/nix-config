{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "usbhid" "sd_mod"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/VM-ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/VM-EFI";
    fsType = "vfat";
  };

  swapDevices = [{device = "/dev/disk/by-label/VM-SWAP";}];

  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
