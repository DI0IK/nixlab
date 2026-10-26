{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    angi = {
      image = "registry.gitlab.com/dhbw_tinf24b6/testing/test:latest";
      autoStart = true;
      environmentFiles = [
        config.sops.secrets."angi-env".path
      ];
      extraOptions = [
        "--pull=always"
      ];
    };
  };

  # Wait for registry login before starting container
  systemd.services."podman-angi" = {
    after = [ "podman-registry-login.service" ];
    wants = [ "podman-registry-login.service" ];
  };
}
