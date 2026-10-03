{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    gitlab-time-analysis = {
      image = "ghcr.io/di0ik/gitlab-time-analysis:main";
      autoStart = true;
      ports = [
        "127.0.0.1:3020:3000"
      ];
      environment = {
        GITLAB_GROUP_PATH = "dhbw-se/se2-tinf24b6";
        GITLAB_DOMAIN = "https://gitlab.com";
        APP_URL = "https://se-timetracking.dominikstahl.dev";
        PROJECT_START_DATE = "2026-10-01";
        PROJECT_END_DATE = "2026-12-24";
        SPRINT_START_WEEKDAY = "4";
        SPRINT_DURATION_WEEKS = "1";
      };
      environmentFiles = [
        config.sops.templates."gitlab-time-analysis.env".path
      ];
    };
  };
}
