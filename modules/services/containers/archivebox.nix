{ ... }:

{
  virtualisation.oci-containers.containers = {
    archivebox = {
      image = "docker.io/archivebox/archivebox:latest";
      autoStart = true;
      ports = [
        "127.0.0.1:8000:8000"
      ];
      environment = {
        ALLOWED_HOSTS = "archive.dominikstahl.dev,localhost,127.0.0.1";
        PUBLIC_INDEX = "False";
        PUBLIC_SNAPSHOTS = "True";
        PUBLIC_ADD_FIELDS = "False";
        SAVE_ARCHIVE_DOT_ORG = "False";
        MEDIA_MAX_SIZE = "750m";
        TIMEOUT = "60";
        CHECK_SSL_VALIDITY = "True";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/persist/var/lib/archivebox:/data"
      ];
    };
  };

  # Impermanence persistence for ArchiveBox data & snapshots
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/archivebox"
    ];
  };
}
