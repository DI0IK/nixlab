{ ... }:

{
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    oci-containers.backend = "podman";
  };

  # Allow rootless / non-root containers to bind to service ports
  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 80;
  };

  # Impermanence persistence for container storage and images
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/containers"
    ];
  };
}
