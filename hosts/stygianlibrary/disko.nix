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

            luks = {
              label = "STYGIAN-LUKS";
              size = "100%";
              content = {
                type = "luks";
                name = "stygiancrypt";
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                  mountOptions = ["noatime" "nodiratime"];
                  extraArgs = ["-F" "-L" "STYGIAN-SYSTEM"];
                };
              };
            };
          };
        };
      };
    };
  };
}
