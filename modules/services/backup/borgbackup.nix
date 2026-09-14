{ config, pkgs, ... }:

{
  services.borgbackup.jobs.homelab = {
    paths = [
      "/persist/var/lib"
      "/persist/etc"
    ];

    exclude = [
      "**/.cache"
      "**/Cache"
      "**/transcodes"
      "**/log"
      "**/logs"
      "/persist/var/lib/containers" # Exclude raw Podman container layers
      "/persist/var/lib/immich/model-cache"
    ];

    repo = "ssh://u599352-sub3@u599352-sub3.your-storagebox.de:23/./";
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
}
