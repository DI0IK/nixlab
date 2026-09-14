{ ... }:
{
  disko.devices = {
    nodev = {
      "/" = {
        type = "nodev";
        fsType = "tmpfs";
        mountOptions = [
          "size=16G"
          "mode=755"
        ];
      };
    };

    disk = {
      main = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
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
                  "@swap" = {
                    mountpoint = "/.swapvol";
                    mountOptions = [
                      "noatime"
                      "nodatacow"
                    ];
                    swap.swapfile.size = "32G";
                  };
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
