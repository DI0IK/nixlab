{ config, pkgs, ... }:

{
  # Automatic NixOS system upgrade from GitHub flake configuration
  system.autoUpgrade = {
    enable = true;
    flake = "github:DI0IK/nixlab#${config.networking.hostName}";
    dates = "04:00";
    flags = [
      "-L"
    ];
    allowReboot = false;
  };

  # Log package version changes between generations upon activation to systemd journal
  system.activationScripts.logSystemDiff = {
    supportsDryActivation = true;
    text = ''
      if [ -e /run/current-system ] && [ -e "$systemConfig" ]; then
        echo "=== NixOS System Upgrade Diff ==="
        PATH="${pkgs.nix}/bin:$PATH" ${pkgs.nvd}/bin/nvd diff /run/current-system "$systemConfig" || true
      fi
    '';
  };
}
