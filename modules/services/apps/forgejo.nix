{ pkgs, ... }:

{
  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    stateDir = "/var/lib/forgejo";
    repositoryRoot = "/var/lib/forgejo/git/gitea-repositories";

    # Connect to host PostgreSQL via local UNIX socket (peer authentication)
    database = {
      type = "postgres";
      user = "forgejo";
      name = "forgejo";
      socket = "/run/postgresql";
      createDatabase = false;
    };

    settings = {
      server = {
        DOMAIN = "git.dominikstahl.dev";
        ROOT_URL = "https://git.dominikstahl.dev/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        LANDING_PAGE = "explore";

        # SSH Configuration (built-in SSH server proxied by Traefik from HAProxy on VPS)
        DISABLE_SSH = false;
        START_SSH_SERVER = true;
        SSH_DOMAIN = "git.dominikstahl.dev";
        SSH_USER = "git";
        BUILTIN_SSH_SERVER_USER = "git";
        SSH_PORT = 22;
        SSH_LISTEN_PORT = 2222;
      };
      service = {
        DISABLE_REGISTRATION = true;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = false;
      };
      session = {
        COOKIE_SECURE = true;
      };
    };
  };

  # Impermanence persistence for Forgejo repositories, SSH keys, and config
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/forgejo"
    ];
  };
}
