{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    archive-viewer = {
      image = "git.dominikstahl.dev/dominik/data_viewer:latest";
      autoStart = true;
      ports = [
        "127.0.0.1:3015:3001"
      ];
      environmentFiles = [
        config.sops.secrets."archive-viewer-env".path
      ];
      volumes = [
        "/data/media:/media:ro"
        "/persist/var/lib/archive-viewer:/data"
      ];
    };
  };

  # Declarative directory creation for persistent SQLite index and cache
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/archive-viewer 0755 1000 1000 -"
  ];

  # Impermanence persistence for index DB and pre-generated JSON indices
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/archive-viewer"
    ];
  };

  # Wait for external NFS media share before starting container
  systemd.services."podman-archive-viewer" = {
    after = [ "data-media.mount" ];
    wants = [ "data-media.mount" ];
  };
}
