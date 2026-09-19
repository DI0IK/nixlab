{ config, pkgs, ... }:

let
  mcRouterSyncScript = pkgs.writeScript "mc-router-sync" (builtins.readFile ./mc-router-sync.py);

  limboConfig = (pkgs.formats.toml { }).generate "server.toml" {
    bind = "127.0.0.1:25564";
    default_game_mode = "spectator";
    welcome_message = "<gold><bold>Calagopus Network</bold></gold>\n<gray>There is no Minecraft server online for this address.</gray>";
    server_list = {
      message_of_the_day = "<gold><bold>Calagopus</bold></gold> <dark_gray>»</dark_gray> <red>Server offline or unrouted</red>";
    };
  };
in
{
  # Host-side directory preparation for MicroVM storage and secrets
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/microvms 0755 root root -"
    "d /persist/var/lib/microvms/calagopus-wings 0750 root root -"
    "d /run/secrets/calagopus-wings 0750 root root -"
  ];

  # Ensure host SOPS secrets are decrypted and plain key is installed before virtiofsd starts
  systemd.services."microvm-virtiofsd@calagopus-wings" = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
    preStart = ''
      mkdir -p /run/secrets/calagopus-wings
      rm -f /run/secrets/calagopus-wings/wg-games.key
      install -m 0400 -o root -g root ${config.sops.secrets."wg-wings-private-key".path} /run/secrets/calagopus-wings/wg-games.key
    '';
  };

  # Order MicroVM after secrets service
  systemd.services."microvm@calagopus-wings" = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
  };

  # Host-side network bridge for MicroVM communication
  networking.bridges.br-microvm.interfaces = [ ];
  networking.interfaces.br-microvm.ipv4.addresses = [
    {
      address = "10.100.0.1";
      prefixLength = 24;
    }
  ];

  # Allow local traffic between host and MicroVM
  networking.firewall.trustedInterfaces = [ "br-microvm" ];

  # NAT outbound traffic so MicroVM has internet access to establish WireGuard to VPS
  networking.nat = {
    enable = true;
    internalInterfaces = [ "br-microvm" ];
  };

  # Impermanence: ensure MicroVM state and virtual disks persist across host reboots
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/microvms"
    ];
  };

  # Calagopus Wings MicroVM definition
  microvm.vms.calagopus-wings = {
    autostart = true;
    config =
      { config, pkgs, ... }:
      {
        system.stateVersion = "24.11";
        nix.gc.automatic = false;

        microvm = {
          vcpu = 4;
          mem = 32768; # 32 GB RAM
          hypervisor = "qemu";
          vsock.cid = 3;
          interfaces = [
            {
              type = "bridge";
              id = "vm-wings";
              bridge = "br-microvm";
              mac = "02:00:00:00:00:01";
            }
          ];
          volumes = [
            {
              image = "/persist/var/lib/microvms/calagopus-wings/disk.img";
              mountPoint = "/var/lib";
              size = 153600; # 150 GB sparse virtual disk
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
              tag = "calagopus-secrets";
              source = "/run/secrets/calagopus-wings";
              mountPoint = "/run/secrets";
              readOnly = true;
            }
          ];
        };

        # Disable predictable interface names so the virtio-net adapter is always eth0
        boot.kernelParams = [ "net.ifnames=0" ];
        networking.usePredictableInterfaceNames = false;

        # Local network interface connected to host bridge
        networking.hostName = "calagopus-wings";
        networking.interfaces.eth0 = {
          ipv4.addresses = [
            {
              address = "10.100.0.2";
              prefixLength = 24;
            }
          ];
        };
        networking.defaultGateway = {
          address = "10.100.0.1";
          interface = "eth0";
        };
        networking.nameservers = [
          "10.100.0.1"
          "1.1.1.1"
        ];

        # Dedicated WireGuard interface to VPS (default route for all game traffic)
        networking.wg-quick.interfaces.wg-games = {
          autostart = true;
          address = [
            "172.30.32.3/24"
            "fd86:ea04:1115::3/128"
          ];
          mtu = 1350;
          privateKeyFile = "/run/secrets/wg-games.key";
          peers = [
            {
              publicKey = "xp2zUi4Dx1wSQwZq3mKL7RwOIKFc9G12LyzinAj/8C4=";
              endpoint = "217.154.87.4:51820";
              allowedIPs = [
                "0.0.0.0/0"
                "::/0"
              ];
              persistentKeepalive = 25;
            }
          ];
          postUp = ''
            ${pkgs.iptables}/bin/iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
          '';
          preDown = ''
            ${pkgs.iptables}/bin/iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || true
          '';
        };

        # Container engine for game servers and helper services
        virtualisation.docker = {
          enable = true;
          daemon.settings = {
            mtu = 1350;
          };
        };

        virtualisation.oci-containers = {
          backend = "docker";
          containers = {
            # Minecraft reverse proxy (multiplexes port 25565 across servers)
            mc-router = {
              image = "docker.io/itzg/mc-router:latest";
              autoStart = true;
              extraOptions = [
                "--network=host"
              ];
              environment = {
                PORT = "25565";
                API_BINDING = "127.0.0.1:8081";
                DEFAULT = "127.0.0.1:25564";
              };
            };

            # Limbo fallback server for unmatched/offline routes
            limbo = {
              image = "ghcr.io/quozul/picolimbo:latest";
              autoStart = true;
              extraOptions = [
                "--network=host"
              ];
              volumes = [
                "${limboConfig}:/etc/picolimbo/server.toml:ro"
              ];
              cmd = [
                "pico_limbo"
                "--config"
                "/etc/picolimbo/server.toml"
              ];
            };

            # Calagopus Wings daemon
            wings = {
              image = "ghcr.io/calagopus/wings:latest";
              autoStart = true;
              extraOptions = [
                "--network=host"
                "--privileged"
              ];
              environment = {
                TZ = "Europe/Berlin";
              };
              volumes = [
                "/var/run/docker.sock:/var/run/docker.sock"
                "/var/lib/calagopus-wings:/var/lib/calagopus-wings"
                "/tmp/calagopus-wings:/tmp/calagopus-wings"
                "/var/lib/calagopus-config:/etc/calagopus-wings"
                "/var/lib/calagopus-config:/etc/pterodactyl"
                "/var/log/calagopus:/var/log/calagopus"
                "/var/log/calagopus:/var/log/pterodactyl"
              ];
            };
          };
        };

        # Ensure config and data directories exist
        systemd.tmpfiles.rules = [
          "d /var/lib/calagopus-wings 0755 root root -"
          "d /var/lib/calagopus-wings/volumes 0755 root root -"
          "d /tmp/calagopus-wings 0755 root root -"
          "d /var/lib/calagopus-config 0750 root root -"
          "d /var/log/calagopus 0750 root root -"
        ];

        # Ensure Limbo fallback is started before mc-router
        systemd.services.docker-mc-router = {
          after = [ "docker-limbo.service" ];
          wants = [ "docker-limbo.service" ];
        };

        # mc-router dynamic route synchronizer
        systemd.services.mc-router-sync = {
          description = "Sync Docker container domains to mc-router API";
          after = [
            "docker.service"
            "docker-mc-router.service"
          ];
          wants = [
            "docker.service"
            "docker-mc-router.service"
          ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.python3}/bin/python3 ${mcRouterSyncScript}";
            Restart = "always";
            RestartSec = "5s";
            User = "root";
          };
        };

        # SSH access for administration
        services.openssh = {
          enable = true;
          settings = {
            PermitRootLogin = "prohibit-password";
            PasswordAuthentication = false;
          };
        };
        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGf6+LjSvCIHUVriHGRqQ1GVMJtW1DkfxCu0gE0SMUc1 dominik@fw13"
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNrhZ9q3SikMV7b7U/DqiGXAA3RO2lXlFX/Fgi8n2w2XQGhwRDzua1NaMwHNzjp2LFOz8tSlkB50RRp7HwFTjnIjKuIhn9hLSsdGmU5UhpnEeS1czO67E+e4bzzBqBX98xeALgNnzJJb68QGokEbvItVSVQP1zRAzEZqETM95ecbCm10gqMw7C7vHCFa1O+pVU3M31IhPZ/zscpSLFkPsbxTODgLn3sh75i+togN6zLtXfXfyz8ATIK2bibaaKu3s2n1Kvq9p+eUgzviGJcHuip8d+hNbiZhBnwTGiLCTa23ZzhO54G8DlOtUnpbAQlmERhHLaYSDKh2/UrGTmE09dExpRqounV0bZwrGNVBPe90xVku9XCbI5BjdXd0IkUzcHSaZMsehA0hCj7cvKTyrHp8N5SOOBJftK2XLJlMV0PhAUy1PD1R6SchdAWQO6/LJb4HETVLq99SS7AgJ1slw9GFUMC+YSI3q91STiat3Y/rAvmnCbQ0jc38g6YpF927Jhbi7+pMdMy0RDSeJ578WQ1dpzr4D9uGOXycW2Z3D33DseLrzHT8r+ps6TK0vTSJu2EEirMFzA0FcQ7pZfXer9FJx3l8VtxzT/JTzVmjkZ3h0tjKqsF4NndzFxB075tcSXMIEg+9smE5drT52dqqcvhzMobI5yzxLvastFiI7jUQ== openpgp:0x174207B6"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdkaglw78zVRC8BA3NZ62CA7WLvx1kUGLOsHOSlEOBJ root@homelab"
        ];

        users.users.pterodactyl = {
          isSystemUser = true;
          uid = 988;
          group = "pterodactyl";
          extraGroups = [ "docker" ];
        };
        users.groups.pterodactyl = {
          gid = 988;
        };

        # Firewall inside the MicroVM
        networking.firewall = {
          enable = true;
          allowedTCPPorts = [
            22    # SSH administration
            2022  # Calagopus SFTP
            8080  # Calagopus Wings API (Panel communication)
            25565 # Minecraft (mc-router multiplexer)
          ];
          allowedUDPPorts = [
            2456  # Valheim game
            2457  # Valheim query
            7777  # Satisfactory
            34197 # Factorio
          ];
          allowedTCPPortRanges = [
            { from = 20000; to = 20010; }
          ];
          allowedUDPPortRanges = [
            { from = 20000; to = 20010; }
          ];
        };
      };
  };
}
