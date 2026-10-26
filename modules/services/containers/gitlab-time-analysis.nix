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
    gitlab-time-analysis-tinf25 = {
      image = "ghcr.io/di0ik/gitlab-time-analysis:main";
      autoStart = true;
      ports = [
        "127.0.0.1:3021:3000"
      ];
      environment = {
        GITLAB_GROUP_PATH = "dhbw-se/software-engineering-i-tinf25b6";
        GITLAB_DOMAIN = "https://gitlab.com";
        APP_URL = "https://se-timetracking-tinf25.dominikstahl.dev";
        PROJECT_START_DATE = "2026-10-01";
        PROJECT_END_DATE = "2027-06-27";
        SPRINT_START_WEEKDAY = "2";
        SPRINT_DURATION_WEEKS = "1";
      };
      environmentFiles = [
        config.sops.templates."gitlab-time-analysis-tinf25.env".path
      ];
    };
    gitlab-time-analysis-v2 = {
      image = "ghcr.io/di0ik/gitlab-time-analysis:v2";
      autoStart = true;
      ports = [
        "127.0.0.1:3022:3000"
      ];
      volumes = [
        "/persist/var/lib/gitlab-time-analysis-v2:/data:Z"
      ];
      environmentFiles = [
        config.sops.secrets."timetracking-v2-env".path
      ];
      environment = {
        APP_URL = "https://timetracking.dominikstahl.dev";
        GITLAB_DOMAIN = "https://gitlab.com";
        SYNC_INTERVAL_SECS = "300";
        GIT_MIRROR_INTERVAL_SECS = "900";
        RUST_LOG = "info,gitlab_platform=info";
      };
      extraOptions = [
        "--pull=always"
      ];
    };
  };

  # Declarative directory creation for persistent database and git mirrors
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/gitlab-time-analysis-v2 0750 1000 1000 -"
  ];

  # Impermanence persistence for SQLite database and bare git mirrors
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/gitlab-time-analysis-v2"
    ];
  };
}
