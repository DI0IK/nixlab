{
  config,
  pkgs,
  lib,
  ...
}:

let
  runnerConfig = pkgs.writeText "forgejo-runner-config.yaml" ''
    runner:
      capacity: 1
      timeout: 3h
      shutdown_timeout: 3h
      insecure: false
      fetch_timeout: 30s
    container:
      docker_host: "unix:///run/podman/podman.sock"
      valid_volumes:
        - "**"
    server:
      connections:
        forgejo:
          url: https://git.dominikstahl.dev/
          uuid: 42025d3d-66fc-4e13-9974-8a8f1edb5c3c
          token_url: file:///run/secrets/token
          labels:
            - "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest"
            - "native:host"
        codeberg:
          url: https://codeberg.org/
          uuid: 3d3b9023-0662-46a6-bef3-655cd10626a5
          token_url: file:///run/secrets/token-codeberg
          labels:
            - "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest"
            - "native:host"
  '';
in
{
  # Host directories for secrets and VM persistent storage
  systemd.tmpfiles.rules = [
    "d /run/secrets/forgejo-runner 0750 root root -"
    "d /persist/var/lib/microvms/forgejo-runner 0775 microvm kvm -"
    "h /persist/var/lib/microvms/forgejo-runner - - - - +C"
  ];

  # Order virtiofsd startup after host secrets are decrypted by sops-nix
  systemd.services."microvm-virtiofsd@forgejo-runner" = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
    preStart = ''
      mkdir -p /run/secrets/forgejo-runner
      rm -f /run/secrets/forgejo-runner/token
      rm -f /run/secrets/forgejo-runner/token-codeberg
      install -m 0400 -o root -g root ${
        config.sops.secrets."forgejo-action-microvm-token".path
      } /run/secrets/forgejo-runner/token
      install -m 0400 -o root -g root ${
        config.sops.secrets."codeberg-action-microvm-token".path
      } /run/secrets/forgejo-runner/token-codeberg
    '';
  };

  systemd.services."microvm@forgejo-runner" = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
  };

  # Forgejo Runner MicroVM definition
  microvm.vms.forgejo-runner = {
    autostart = true;
    config =
      { pkgs, ... }:
      {
        system.stateVersion = "24.11";

        microvm = {
          vcpu = 6;
          mem = 16384;
          hypervisor = "qemu";
          interfaces = [
            {
              type = "bridge";
              id = "vm-forgejo";
              bridge = "br-microvm";
              mac = "02:00:00:00:00:30";
            }
          ];
          shares = [
            {
              proto = "virtiofs";
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
            }
            {
              proto = "virtiofs";
              tag = "runner-secrets";
              source = "/run/secrets/forgejo-runner";
              mountPoint = "/run/secrets";
              readOnly = true;
            }
          ];
          writableStoreOverlay = "/nix/.rw-store";
          volumes = [
            {
              image = "/persist/var/lib/microvms/forgejo-runner/disk.img";
              mountPoint = "/";
              size = 102400; # 100 GB sparse persistent disk
              autoCreate = true;
              fsType = "ext4";
            }
          ];
        };

        # Periodic cleanup of old container images, stopped containers, and build cache
        systemd.services.podman-cleanup = {
          description = "Clean up old Podman containers, images, and build cache";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "podman-cleanup" ''
              # Remove stopped containers
              ${pkgs.podman}/bin/podman container prune -f
              # Remove unused images and build cache older than 7 days
              ${pkgs.podman}/bin/podman system prune -a --volumes -f --filter "until=168h"
            '';
          };
        };

        systemd.timers.podman-cleanup = {
          description = "Daily cleanup of old Podman data";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };

        # In-guest zram swap: transparently compresses memory pages to avoid OOM on peak builds
        zramSwap = {
          enable = true;
          memoryPercent = 100;
        };

        # Disable predictable interface names so the virtio-net adapter is always eth0
        boot.kernelParams = [ "net.ifnames=0" ];
        networking.usePredictableInterfaceNames = false;

        # Guest Network Configuration: static IP 10.100.0.30, isolated from LAN via host firewall
        networking.hostName = "forgejo-runner";
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.100.0.30";
            prefixLength = 24;
          }
        ];
        networking.defaultGateway = {
          address = "10.100.0.1";
          interface = "eth0";
        };
        networking.nameservers = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        # Podman container runtime for Docker workflow actions
        virtualisation.podman = {
          enable = true;
          dockerCompat = true;
          dockerSocket.enable = true;
        };

        # Enable Nix flakes and CLI tools for host-mode builds
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        environment.systemPackages = with pkgs; [
          git
          bash
          coreutils
          curl
          jq
          nix
          devenv
          nodejs_22
        ];

        nix.settings = {
          trusted-users = [ "root" ];
          substituters = [
            "https://cache.nixos.org"
            "https://devenv.cachix.org"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          ];
          auto-optimise-store = false;
        };

        # Forgejo Runner Daemon Service
        systemd.services.forgejo-runner = {
          description = "Forgejo Runner Daemon";
          after = [
            "network-online.target"
            "podman.socket"
            "podman.service"
            "nix-daemon.socket"
            "nix-daemon.service"
          ];
          wants = [
            "network-online.target"
            "podman.socket"
            "podman.service"
            "nix-daemon.socket"
            "nix-daemon.service"
          ];
          wantedBy = [ "multi-user.target" ];
          path = [
            pkgs.git
            pkgs.podman
            pkgs.bash
            pkgs.coreutils
            pkgs.nix
            pkgs.devenv
            pkgs.nodejs_22
          ];
          environment = {
            HOME = "/root";
            NIX_REMOTE = "daemon";
          };
          serviceConfig = {
            Type = "simple";
            WorkingDirectory = "/root";
            StandardOutput = "journal";
            StandardError = "journal";
            ExecStart = "${pkgs.forgejo-runner}/bin/forgejo-runner daemon -c ${runnerConfig}";
            Restart = "always";
            RestartSec = 10;
          };
        };
      };
  };
}
