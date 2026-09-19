{ config, ... }:

{
  imports = [
    # Hardware & Storage
    ./hardware.nix
    ./disk.nix

    # Core & Impermanence
    ../../modules/core
    ../../modules/core/impermanence.nix

    # Security
    ../../modules/security/sshd.nix
    ../../modules/security/firewall.nix
    ../../modules/security/sops.nix
    ../../modules/security/acme.nix

    # Networking & Ingress
    ../../modules/services/network/wireguard-vps.nix
    ../../modules/services/network/traefik.nix
    ../../modules/services/network/guacamole.nix

    # Centralized Databases & Cache
    ../../modules/services/databases/postgres.nix
    ../../modules/services/databases/valkey.nix

    # Media & Streaming
    ../../modules/services/media/jellyfin.nix
    ../../modules/services/media/arr.nix
    ../../modules/services/media/navidrome.nix

    # Automation & Apps
    ../../modules/services/automation/home-assistant.nix
    ../../modules/services/apps/forgejo.nix
    ../../modules/services/apps/adguard.nix
    ../../modules/services/apps/searxng.nix
    ../../modules/services/apps/thelounge.nix
    ../../modules/services/apps/homepage.nix
    ../../modules/services/apps/paperless.nix
    ../../modules/services/apps/ycast.nix

    # Containers (Podman)
    ../../modules/services/containers/podman.nix
    ../../modules/services/containers/immich.nix
    ../../modules/services/containers/authentik.nix
    ../../modules/services/containers/archivebox.nix
    ../../modules/services/containers/misc.nix
    ../../modules/services/containers/calagopus.nix

    # Virtual Machines (MicroVM)
    ../../modules/services/vms/calagopus-wings

    # Backup
    ../../modules/services/backup/borgbackup.nix

    # Monitoring & Metrics
    ../../modules/services/monitoring
  ];

  networking.hostName = "homelab";
  networking.domain = "dominikstahl.dev";

  # External NFS media share (containing media/, torrent/, usenet/)
  fileSystems."/data/media" = {
    device = "192.168.179.10:/mnt/user/media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
      "nfsvers=4.2"
      "rw"
      "soft"
    ];
  };

  # Immich Primary Photo Library (NFS on TrueNAS pool1)
  fileSystems."/mnt/immich-library" = {
    device = "192.168.179.101:/mnt/pool1/Media/Bilder_Immich";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
      "rw"
      "soft"
    ];
  };

  # Immich External Read-Only Photo Library (Bilder)
  fileSystems."/mnt/immich-external" = {
    device = "192.168.179.101:/mnt/pool1/Media/Bilder";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
      "ro"
      "soft"
    ];
  };

  # Immich External Read-Only Photo Library (Manger)
  fileSystems."/mnt/immich-external-manger" = {
    device = "192.168.179.101:/mnt/pool1/Home/Manger/Bilder";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
      "ro"
      "soft"
    ];
  };

  # Immich External Read-Only Photo Library (Old NAS SMB Share)
  fileSystems."/mnt/immich-external-old-nas" = {
    device = "//192.168.178.21/Bilder";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
      "ro"
      "credentials=${config.sops.templates."cifs-old-nas-credentials".path}"
    ];
  };

  # State version for NixOS configuration
  system.stateVersion = "24.11";
}
