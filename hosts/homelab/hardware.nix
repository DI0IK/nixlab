{ pkgs, ... }:

{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Systemd-boot EFI bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Intel CPU Microcode
  hardware.cpu.intel.updateMicrocode = true;

  # Intel QuickSync (UHD Graphics 630) VA-API acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vpl-gpu-rt
      intel-compute-runtime
      ocl-icd
    ];
  };

  # Host performance and networking sysctl tunings
  boot.kernel.sysctl = {
    # Increase inotify watches for media servers and *arr indexers
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
    # BBR congestion control and buffer sizes
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
  };
}
