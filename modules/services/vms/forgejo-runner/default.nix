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
  # Add qemu-utils to host environment for qemu-img and qemu-nbd
  environment.systemPackages = [ pkgs.qemu-utils ];

  # Ensure NBD module is available on the host for base image refresh
  boot.kernelModules = [ "nbd" ];

  # Host directories for secrets, base image storage, and ephemeral run overlay
  systemd.tmpfiles.rules = [
    "d /run/secrets/forgejo-runner 0750 root root -"
    "d /persist/var/lib/microvms/forgejo-runner 0775 microvm kvm -"
    "h /persist/var/lib/microvms/forgejo-runner - - - - +C"
    "d /run/microvms/forgejo-runner 0775 microvm kvm -"
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

  # MicroVM host service: prepare fresh ephemeral overlay before VM starts
  systemd.services."microvm@forgejo-runner" = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
    serviceConfig = {
      PermissionsStartOnly = true;
    };
    preStart = ''
      ${pkgs.coreutils}/bin/mkdir -p /run/microvms/forgejo-runner
      ${pkgs.coreutils}/bin/chown microvm:kvm /run/microvms/forgejo-runner
      ${pkgs.coreutils}/bin/chmod 0775 /run/microvms/forgejo-runner

      BASE_IMG="/persist/var/lib/microvms/forgejo-runner/base.qcow2"
      OVERLAY_IMG="/run/microvms/forgejo-runner/overlay.qcow2"

      if [ ! -f "$BASE_IMG" ]; then
        echo "Base image ($BASE_IMG) does not exist yet. Please run initial fill with: systemctl start forgejo-runner-refresh-base"
        exit 1
      fi

      # Wipe stale job overlay and create a fresh COW layer pointing to base
      ${pkgs.coreutils}/bin/rm -f "$OVERLAY_IMG"
      ${pkgs.qemu-utils}/bin/qemu-img create -f qcow2 -b "$BASE_IMG" -F qcow2 "$OVERLAY_IMG"
      ${pkgs.coreutils}/bin/chown microvm:kvm "$OVERLAY_IMG"
      ${pkgs.coreutils}/bin/chmod 0660 "$OVERLAY_IMG"
    '';
  };

  # Weekly refresh timer & service to update golden base image
  systemd.timers.forgejo-runner-refresh-base = {
    description = "Weekly Refresh Timer for Forgejo Runner Base Image";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 07:00:00";
      Persistent = true;
    };
  };

  systemd.services.forgejo-runner-refresh-base = {
    description = "Refresh Forgejo Runner Base Image";
    path = with pkgs; [
      bash
      qemu-utils
      e2fsprogs
      podman
      util-linux
      coreutils
      kmod
      systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = "1h";
    };
    script = ''
      set -euo pipefail

      BASE_DIR="/persist/var/lib/microvms/forgejo-runner"
      BASE_IMG="$BASE_DIR/base.qcow2"
      NEW_IMG="$BASE_DIR/base-new.qcow2"
      TMP_MNT="/run/microvms/forgejo-runner/mnt-base-refresh"
      RUN_ROOT="/run/podman-base-refresh"
      NBD_DEV=""

      cleanup() {
        local exit_code=$?
        set +e
        if mountpoint -q "$TMP_MNT"; then
          umount -f "$TMP_MNT" || true
        fi
        if [ -n "$NBD_DEV" ]; then
          qemu-nbd -d "$NBD_DEV" || true
        fi
        rm -rf "$TMP_MNT" "$RUN_ROOT"
        if [ "$exit_code" -ne 0 ] && [ -f "$NEW_IMG" ]; then
          rm -f "$NEW_IMG"
        fi
      }
      trap cleanup EXIT

      modprobe nbd max_part=8 || true

      for i in $(seq 0 15); do
        dev="/dev/nbd$i"
        if [ -b "$dev" ]; then
          size=$(cat "/sys/class/block/nbd$i/size" 2>/dev/null || echo 0)
          if [ "$size" -eq 0 ]; then
            NBD_DEV="$dev"
            break
          fi
        fi
      done

      if [ -z "$NBD_DEV" ]; then
        echo "ERROR: No available /dev/nbd device found!"
        exit 1
      fi

      echo "Using NBD device: $NBD_DEV"

      mkdir -p "$BASE_DIR"
      mkdir -p "$TMP_MNT"
      mkdir -p "$RUN_ROOT"
      rm -f "$NEW_IMG"

      echo "Creating 40 GiB sparse qcow2 image at $NEW_IMG..."
      qemu-img create -f qcow2 "$NEW_IMG" 40G

      echo "Connecting $NEW_IMG to $NBD_DEV..."
      qemu-nbd --fork -c "$NBD_DEV" -f qcow2 "$NEW_IMG"

      # Wait for kernel block layer to register the NBD device size
      udevadm settle || true
      for _ in $(seq 1 50); do
        dev_size=$(cat "/sys/class/block/$(basename "$NBD_DEV")/size" 2>/dev/null || echo 0)
        if [ "$dev_size" -gt 0 ]; then
          break
        fi
        sleep 0.1
      done

      dev_size=$(cat "/sys/class/block/$(basename "$NBD_DEV")/size" 2>/dev/null || echo 0)
      if [ "$dev_size" -eq 0 ]; then
        echo "ERROR: $NBD_DEV size is still 0 after connecting!"
        exit 1
      fi

      echo "Formatting $NBD_DEV with ext4..."
      mkfs.ext4 -F -L "runner-disk" "$NBD_DEV"

      echo "Populating golden disk via private mount namespace matching guest /var/lib/containers..."
      unshare --mount --propagation private ${pkgs.bash}/bin/bash -euo pipefail -c "
        mount --make-rprivate /
        mkdir -p '$TMP_MNT'
        mount '$NBD_DEV' '$TMP_MNT'
        mkdir -p /var/lib/containers
        mount --bind '$TMP_MNT' /var/lib/containers

        echo 'Pulling runner image into golden container storage...'
        podman --runroot '$RUN_ROOT' pull ghcr.io/catthehacker/ubuntu:act-latest

        echo 'Syncing filesystem...'
        sync

        umount /var/lib/containers
        umount '$TMP_MNT'
      "

      echo "Disconnecting NBD device $NBD_DEV..."
      qemu-nbd -d "$NBD_DEV"
      NBD_DEV=""

      echo "Setting permissions on new base image..."
      chown microvm:kvm "$NEW_IMG"
      chmod 444 "$NEW_IMG"

      echo "Atomically replacing $BASE_IMG with new image..."
      mv -f "$NEW_IMG" "$BASE_IMG"

      rm -rf "$TMP_MNT" "$RUN_ROOT"

      echo "Restarting runner service if running..."
      systemctl try-restart microvm@forgejo-runner.service || true

      echo "Forgejo runner base image refresh completed successfully!"
    '';
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
          qemu.extraArgs = [
            "-drive"
            "id=vdcontainers,format=qcow2,file=/run/microvms/forgejo-runner/overlay.qcow2,if=none,aio=io_uring,discard=unmap"
            "-device"
            "virtio-blk-pci,drive=vdcontainers,serial=containers"
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
              image = "/persist/var/lib/microvms/forgejo-runner/nix-store-overlay.img";
              mountPoint = "/nix/.rw-store";
              size = 40960;
              label = "nix-overlay";
              autoCreate = true;
              fsType = "ext4";
            }
            {
              image = "/persist/var/lib/microvms/forgejo-runner/nix-var.img";
              mountPoint = "/nix/var";
              size = 4096;
              label = "nix-var";
              autoCreate = true;
              fsType = "ext4";
            }
          ];
        };

        # Containers storage volume (QCOW2 COW overlay on top of golden base image)
        fileSystems."/var/lib/containers" = {
          device = "/dev/disk/by-label/runner-disk";
          fsType = "ext4";
          options = [ "defaults" ];
        };

        # Ephemeral root: 2 GB in-memory filesystem for tiny runtime files, /tmp, and /run
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
          options = [
            "defaults"
            "size=2G"
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
