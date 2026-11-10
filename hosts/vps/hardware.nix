{ ... }:

{
  boot.initrd.availableKernelModules = [
    "virtio_net"
    "virtio_pci"
    "virtio_mmio"
    "virtio_blk"
    "virtio_scsi"
    "virtio_balloon"
    "9p"
    "9pnet_virtio"
    "ata_piix"
    "uhci_hcd"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "tcp_bbr" ];
  boot.extraModulePackages = [ ];

  # Systemd-boot EFI bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Stable, non-predictable interface naming (guarantees eth0 across cloud hypervisors)
  boot.kernelParams = [ "net.ifnames=0" ];
  networking.usePredictableInterfaceNames = false;

  # Networking and forwarding sysctl optimizations
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
  };
}
