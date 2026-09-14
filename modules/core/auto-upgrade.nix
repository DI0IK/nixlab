{ ... }:

{
  # Automatic NixOS system upgrade from GitHub flake configuration
  system.autoUpgrade = {
    enable = true;
    flake = "github:DI0IK/nixlab#homelab";
    dates = "04:00";
    flags = [
      "-L"
    ];
    allowReboot = false;
  };
}
