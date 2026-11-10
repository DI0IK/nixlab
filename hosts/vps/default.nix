{ config, ... }:

{
  imports = [
    # Storage & Hardware
    ./disk.nix
    ./hardware.nix

    # Core System, User Management & Impermanence
    ../../modules/core
    ../../modules/core/impermanence.nix

    # Security
    ../../modules/security/sshd.nix
    ../../modules/security/sops.nix
    ../../modules/security/acme.nix
    ./secrets.nix

    # Network Services, Ingress & Routing
    ../../modules/services/network/wireguard-server.nix
    ../../modules/services/network/haproxy.nix
    ../../modules/services/network/vps-routing.nix

    # External Monitoring & Alerting
    ../../modules/services/monitoring/gatus.nix
    ../../modules/services/monitoring/ntfy.nix
    ../../modules/services/monitoring/node-exporter.nix
  ];

  networking.hostName = "vps";
  networking.domain = "dominikstahl.dev";

  # VPS OpenSSH administration on dedicated port 22222 (port 22 is proxied to Forgejo Git SSH)
  services.openssh.ports = [ 22222 ];

  # ACME Certificate for VPS Services (status & ntfy)
  security.acme.certs."vps-services" = {
    domain = "status.dominikstahl.dev";
    extraDomainNames = [
      "ntfy.dominikstahl.dev"
    ];
    dnsProvider = "cloudflare";
    environmentFile = config.sops.templates."acme-cf.env".path;
    group = "certs";
    reloadServices = [
      "haproxy.service"
    ];
    postRun = ''
      cat fullchain.pem key.pem > full.pem
      chmod 640 full.pem
    '';
  };

  # Grant HAProxy read permissions for certificates
  users.users.haproxy.extraGroups = [ "certs" ];

  # State version for NixOS configuration
  system.stateVersion = "24.11";
}
