{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    angi = {
      image = "registry.gitlab.com/dhbw_tinf24b6/testing/test:latest";
      autoStart = false;
      environmentFiles = [
        config.sops.secrets."angi-env".path
      ];
      extraOptions = [
        "--pull=always"
      ];
    };
  };

  # Wait for GitLab registry login before starting container
  systemd.services."podman-angi" = {
    after = [ "podman-registry-login.service" ];
    wants = [ "podman-registry-login.service" ];
  };

  # Periodic timer to run the one-shot bot
  systemd.timers."podman-angi" = {
    description = "Run Angi GitLab bot periodically";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnCalendar = "*:0/5"; # Every 5 minutes
      Persistent = true;
    };
  };
}
