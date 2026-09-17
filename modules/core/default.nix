{ config, pkgs, ... }:

{
  imports = [
    ./auto-upgrade.nix
  ];

  # Allow unfree packages (e.g. unrar for SABnzbd)
  nixpkgs.config.allowUnfree = true;

  # Nix daemon settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    warn-dirty = false;
  };

  # Automatic Nix store garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Timezone and Locale
  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_US.UTF-8";

  # Base administrative and diagnostic tools
  environment.systemPackages = with pkgs; [
    vim
    neovim
    git
    curl
    wget
    rsync
    btop
    htop
    jq
    tmux
    pciutils
    usbutils
    intel-gpu-tools
    wireguard-tools
    tree
    parted
    btrfs-progs
    cifs-utils
    age
    sops
  ];

  # User management
  users.mutableUsers = false;

  users.users.root = {
    hashedPasswordFile = config.sops.secrets."admin-password-hash".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGf6+LjSvCIHUVriHGRqQ1GVMJtW1DkfxCu0gE0SMUc1 dominik@fw13"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNrhZ9q3SikMV7b7U/DqiGXAA3RO2lXlFX/Fgi8n2w2XQGhwRDzua1NaMwHNzjp2LFOz8tSlkB50RRp7HwFTjnIjKuIhn9hLSsdGmU5UhpnEeS1czO67E+e4bzzBqBX98xeALgNnzJJb68QGokEbvItVSVQP1zRAzEZqETM95ecbCm10gqMw7C7vHCFa1O+pVU3M31IhPZ/zscpSLFkPsbxTODgLn3sh75i+togN6zLtXfXfyz8ATIK2bibaaKu3s2n1Kvq9p+eUgzviGJcHuip8d+hNbiZhBnwTGiLCTa23ZzhO54G8DlOtUnpbAQlmERhHLaYSDKh2/UrGTmE09dExpRqounV0bZwrGNVBPe90xVku9XCbI5BjdXd0IkUzcHSaZMsehA0hCj7cvKTyrHp8N5SOOBJftK2XLJlMV0PhAUy1PD1R6SchdAWQO6/LJb4HETVLq99SS7AgJ1slw9GFUMC+YSI3q91STiat3Y/rAvmnCbQ0jc38g6YpF927Jhbi7+pMdMy0RDSeJ578WQ1dpzr4D9uGOXycW2Z3D33DseLrzHT8r+ps6TK0vTSJu2EEirMFzA0FcQ7pZfXer9FJx3l8VtxzT/JTzVmjkZ3h0tjKqsF4NndzFxB075tcSXMIEg+9smE5drT52dqqcvhzMobI5yzxLvastFiI7jUQ== openpgp:0x174207B6"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdkaglw78zVRC8BA3NZ62CA7WLvx1kUGLOsHOSlEOBJ root@homelab"
    ];
  };

  users.users.dominik = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."admin-password-hash".path;
    extraGroups = [
      "wheel"
      "video"
      "render"
      "networkmanager"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGf6+LjSvCIHUVriHGRqQ1GVMJtW1DkfxCu0gE0SMUc1 dominik@fw13"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNrhZ9q3SikMV7b7U/DqiGXAA3RO2lXlFX/Fgi8n2w2XQGhwRDzua1NaMwHNzjp2LFOz8tSlkB50RRp7HwFTjnIjKuIhn9hLSsdGmU5UhpnEeS1czO67E+e4bzzBqBX98xeALgNnzJJb68QGokEbvItVSVQP1zRAzEZqETM95ecbCm10gqMw7C7vHCFa1O+pVU3M31IhPZ/zscpSLFkPsbxTODgLn3sh75i+togN6zLtXfXfyz8ATIK2bibaaKu3s2n1Kvq9p+eUgzviGJcHuip8d+hNbiZhBnwTGiLCTa23ZzhO54G8DlOtUnpbAQlmERhHLaYSDKh2/UrGTmE09dExpRqounV0bZwrGNVBPe90xVku9XCbI5BjdXd0IkUzcHSaZMsehA0hCj7cvKTyrHp8N5SOOBJftK2XLJlMV0PhAUy1PD1R6SchdAWQO6/LJb4HETVLq99SS7AgJ1slw9GFUMC+YSI3q91STiat3Y/rAvmnCbQ0jc38g6YpF927Jhbi7+pMdMy0RDSeJ578WQ1dpzr4D9uGOXycW2Z3D33DseLrzHT8r+ps6TK0vTSJu2EEirMFzA0FcQ7pZfXer9FJx3l8VtxzT/JTzVmjkZ3h0tjKqsF4NndzFxB075tcSXMIEg+9smE5drT52dqqcvhzMobI5yzxLvastFiI7jUQ== openpgp:0x174207B6"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdkaglw78zVRC8BA3NZ62CA7WLvx1kUGLOsHOSlEOBJ root@homelab"
    ];
  };

  # Sudo configuration
  security.sudo.wheelNeedsPassword = false;
}
