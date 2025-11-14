_: {
  disko = {
    enableConfig = false;

    imageBuilder = {
      name = "stygianlibrary-usb";
      imageFormat = "raw";
    };

    devices = {
      disk.stygian = {
        type = "disk";
        device = "/dev/vda";
        imageName = "stygianlibrary";
        imageSize = "64G";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              label = "boot";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["defaults"];
                extraArgs = ["-n" "STYGIAN-EFI"];
              };
            };

            system = {
              label = "system";
              size = "32G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = ["noatime" "nodiratime"];
                extraArgs = ["-F" "-L" "STYGIAN-SYSTEM"];
              };
            };

            persist = {
              label = "persist";
              size = "16G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/persist";
                mountOptions = ["noatime" "nodev" "nosuid"];
                extraArgs = ["-F" "-L" "STYGIAN-PERSIST"];
              };
            };

            models = {
              label = "models";
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/models";
                mountOptions = ["noatime" "nodev" "nosuid"];
                extraArgs = ["-F" "-L" "STYGIAN-MODELS"];
              };
            };
          };
        };
      };
    };
  };
}
