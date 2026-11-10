{ lib, ... }:

{
  disko.devices = {
    nodev."/" = {
      type = "nodev";
      fsType = "tmpfs";
      mountOptions = [
        "size=1G"
        "mode=755"
      ];
    };

    disk.main = {
      device = lib.mkDefault "/dev/vda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            name = "ESP";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            priority = 2;
            name = "swap";
            size = "4G";
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
          root = {
            priority = 3;
            name = "root";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };

  # Impermanence safety: ensure /persist is mounted early in stage-2
  fileSystems."/persist".neededForBoot = true;
}
