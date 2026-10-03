{ config, pkgs, ... }:

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
  '';
in
{
  # Ensure host directory for the SOPS decrypted secret and image cache exists
  systemd.tmpfiles.rules = [
    "d /run/secrets/forgejo-runner 0750 root root -"
    "d /persist/var/lib/microvms/forgejo-runner 0775 microvm kvm -"
    "h /persist/var/lib/microvms/forgejo-runner - - - - +C"
    "d /persist/var/lib/microvms/forgejo-runner/cache 0777 microvm kvm -"
    "h /persist/var/lib/microvms/forgejo-runner/cache - - - - +C"
  ];

  # Order virtiofsd and MicroVM startup after host secrets are decrypted by sops-nix
  systemd.services."microvm-virtiofsd@forgejo-runner" = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
    preStart = ''
      mkdir -p /run/secrets/forgejo-runner
      rm -f /run/secrets/forgejo-runner/token
      install -m 0400 -o root -g root ${
        config.sops.secrets."forgejo-action-microvm-token".path
      } /run/secrets/forgejo-runner/token

      mkdir -p /persist/var/lib/microvms/forgejo-runner/cache
      chown microvm:kvm /persist/var/lib/microvms/forgejo-runner/cache
      chmod 0777 /persist/var/lib/microvms/forgejo-runner/cache
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
          mem = 16384; # 16 GB RAM for tmpfs builds
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
            {
              proto = "virtiofs";
              tag = "runner-cache";
              source = "/persist/var/lib/microvms/forgejo-runner/cache";
              mountPoint = "/var/cache/runner";
            }
          ];
        };

        # Ephemeral root: 16 GB in-memory filesystem for large build workspaces (Rust target/, Android Gradle)
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
          options = [
            "defaults"
            "size=16G"
            "mode=755"
          ];
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
        ];

        # Ephemeral One-Job Runner Service
        systemd.services.forgejo-runner = {
          description = "Forgejo Ephemeral One-Job Runner";
          after = [
            "network-online.target"
            "podman.socket"
            "podman.service"
          ];
          wants = [
            "network-online.target"
            "podman.socket"
            "podman.service"
          ];
          wantedBy = [ "multi-user.target" ];
          path = [
            pkgs.git
            pkgs.podman
            pkgs.bash
            pkgs.coreutils
            pkgs.nix
          ];
          environment = {
            HOME = "/root";
          };
          serviceConfig = {
            Type = "simple";
            WorkingDirectory = "/root";
            StandardOutput = "journal";
            StandardError = "journal";
            ExecStartPre = pkgs.writeShellScript "load-cached-runner-image" ''
              set -euo pipefail
              mkdir -p /var/cache/runner
              IMAGE_TAR="/var/cache/runner/ubuntu-act-latest.tar"
              IMAGE_TAG="ghcr.io/catthehacker/ubuntu:act-latest"

              if [ -s "$IMAGE_TAR" ]; then
                echo "Loading cached runner image from host storage..."
                ${pkgs.podman}/bin/podman load -i "$IMAGE_TAR"
              else
                echo "Pulling runner image from registry..."
                ${pkgs.podman}/bin/podman pull "$IMAGE_TAG"
                echo "Caching runner image to host storage..."
                ${pkgs.podman}/bin/podman save "$IMAGE_TAG" -o "$IMAGE_TAR.tmp"
                mv "$IMAGE_TAR.tmp" "$IMAGE_TAR"
              fi
            '';
            ExecStart = "${pkgs.forgejo-runner}/bin/forgejo-runner one-job -w -c ${runnerConfig}";
            Restart = "on-failure";
            RestartSec = 10;
            SuccessAction = "reboot";
          };
        };
      };
  };
}
