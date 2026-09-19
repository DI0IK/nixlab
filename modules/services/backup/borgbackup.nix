{ config, pkgs, ... }:

{
  services.borgbackup.jobs.homelab = {
    paths = [
      "/persist/var/lib"
      "/persist/etc"
      "/persist/var/backup"
    ];

    exclude = [
      # General caches and temporary files
      "sh:**/cache"
      "sh:**/cache/**"
      "sh:**/.cache"
      "sh:**/.cache/**"
      "sh:**/Cache"
      "sh:**/Cache/**"
      "sh:**/tmp"
      "sh:**/tmp/**"
      "sh:**/temp"
      "sh:**/temp/**"
      "sh:**/.tmp"
      "sh:**/.tmp/**"
      "sh:**/transcode"
      "sh:**/transcode/**"
      "sh:**/transcodes"
      "sh:**/transcodes/**"

      # Container runtimes and ML models
      "pp:/persist/var/lib/containers"
      "pp:/persist/var/lib/immich/model-cache"

      # Active PostgreSQL cluster (rely on clean nightly logical dumps in /persist/var/backup)
      "pp:/persist/var/lib/postgresql"

      # Jellyfin regenerable assets & internal backups
      "pp:/persist/var/lib/jellyfin/data/trickplay"
      "pp:/persist/var/lib/jellyfin/metadata"
      "pp:/persist/var/lib/jellyfin/data/backups"
      "pp:/persist/var/lib/jellyfin/data/SQLiteBackups"

      # Forgejo search indexers & archives
      "pp:/persist/var/lib/forgejo/indexers"
      "pp:/persist/var/lib/forgejo/data/tmp"
      "pp:/persist/var/lib/forgejo/repo-archive"

      # Arr suite artwork & internal duplicate backups
      "sh:**/MediaCover"
      "sh:**/MediaCover/**"
      "sh:**/Backups"
      "sh:**/Backups/**"
      "sh:**/sabnzbd/Downloads"
      "sh:**/sabnzbd/Downloads/**"

      # AdGuard high-churn query logs
      "sh:**/AdGuardHome/data/**/querylog.json*"

      # Ephemeral monitoring TSDBs & chunks
      "pp:/persist/var/lib/prometheus2"
      "pp:/persist/var/lib/loki"

      # System crash dumps
      "pp:/persist/var/lib/systemd/coredump"

      # Internal duplicate backup tarballs & scratch files
      "sh:**/hass/backups"
      "sh:**/hass/backups/**"
      "sh:**/qui/backups"
      "sh:**/qui/backups/**"
      "sh:**/*.corrupted-backup"

      # Logs (including IRC chat logs in /thelounge/logs, HA logs, system logs)
      "sh:**/log"
      "sh:**/log/**"
      "sh:**/logs"
      "sh:**/logs/**"
      "sh:**/home-assistant.log*"
      "pp:/persist/var/log"
      "pp:/persist/var/lib/thelounge/logs"
    ];

    repo = "ssh://u599352-sub3@u599352-sub3.your-storagebox.de:23/./homelab";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets."borg-repo-passphrase".path}";
    };

    environment = {
      BORG_RSH = "ssh -p 23 -i ${
        config.sops.secrets."system-ssh-key".path
      } -o StrictHostKeyChecking=accept-new";
    };

    compression = "auto,zstd";
    startAt = "*-*-* 04:00:00";

    prune.keep = {
      within = "1d";
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };

  # Impermanence persistence for Borg cache (chunks/files index) and security config
  environment.persistence."/persist" = {
    directories = [
      "/root/.cache/borg"
      "/root/.config/borg"
    ];
  };
}
