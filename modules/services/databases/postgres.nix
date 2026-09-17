{ pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    package = pkgs.postgresql_17;
    extensions = ps: [ ps.pgvector ];

    # Declarative databases and owners
    ensureDatabases = [
      "forgejo"
      "authentik"
      "immich"
      "guacamole"
      "paperless"
    ];

    ensureUsers = [
      {
        name = "forgejo";
        ensureDBOwnership = true;
      }
      {
        name = "authentik";
        ensureDBOwnership = true;
      }
      {
        name = "immich";
        ensureDBOwnership = true;
      }
      {
        name = "guacamole";
        ensureDBOwnership = true;
      }
      {
        name = "paperless";
        ensureDBOwnership = true;
      }
    ];

    # Authentication: trust local UNIX socket and TCP loopback
    # No passwords required for native services or host-networked containers
    authentication = ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
      host    guacamole       guacamole       10.88.0.0/16            trust
    '';

    # Server performance tuning for 96GB RAM Optiplex host
    settings = {
      shared_buffers = "4GB";
      work_mem = "64MB";
      maintenance_work_mem = "1GB";
      effective_cache_size = "16GB";
      max_connections = 500;
      wal_buffers = "16MB";
      checkpoint_completion_target = 0.9;
    };
  };

  # Automated nightly logical database backups
  services.postgresqlBackup = {
    enable = true;
    databases = [
      "forgejo"
      "authentik"
      "immich"
      "guacamole"
      "paperless"
    ];
    location = "/var/backup/postgresql";
    startAt = "*-*-* 03:00:00";
  };

  # Impermanence persistence for database clusters and automated dumps
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/postgresql"
      "/var/backup/postgresql"
    ];
  };
}
