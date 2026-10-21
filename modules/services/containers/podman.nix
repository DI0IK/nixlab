{ config, pkgs, ... }:

{
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    oci-containers.backend = "podman";
  };

  # Automatically log in to local Forgejo registry using token from SOPS
  systemd.services.podman-registry-login = {
    description = "Login Podman to internal Forgejo container registry";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "10s";
    };
    script = ''
      mkdir -p /etc/containers /root/.config/containers
      TOKEN=$(cat ${config.sops.secrets."homelab-forgejo-image-pull-access-token".path})
      ${pkgs.podman}/bin/podman login --authfile /etc/containers/auth.json --username dominik --password-stdin git.dominikstahl.dev <<< "$TOKEN"
      cp /etc/containers/auth.json /root/.config/containers/auth.json
    '';
  };

  # Allow rootless / non-root containers to bind to service ports
  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 80;
  };

  # Impermanence persistence for container storage, images, and registry credentials
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/containers"
      "/root/.config/containers"
    ];
    files = [
      "/etc/containers/auth.json"
    ];
  };
}
