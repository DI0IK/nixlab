{ ... }:

{
  virtualisation.oci-containers.containers = {
    nextcloud-archiver = {
      image = "git.dominikstahl.dev/dominik/nextcloud_archiver:v0.2.0";
      autoStart = true;
      ports = [
        "127.0.0.1:8085:8080"
      ];
      volumes = [
        "/persist/var/lib/keks_nextcloud_archive:/data"
      ];
    };
  };

  # Impermanence persistence for Nextcloud archive data
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/keks_nextcloud_archive"
    ];
  };
}
