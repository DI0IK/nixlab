{ ... }:

{
  virtualisation.oci-containers.containers = {
    internet-tracker = {
      image = "git.dominikstahl.dev/dominik/internet_tracker:latest";
      autoStart = true;
      ports = [
        "127.0.0.1:3030:3000"
      ];
      volumes = [
        "/persist/var/lib/internet-tracker:/data"
      ];
      extraOptions = [
        "--pull=always"
        "--cap-add=NET_RAW"
      ];
      environment = {
        PORT = "3000";
        DB_PATH = "/data/ping_results.db";
      };
    };
  };

  # Declarative directory creation for persistent SQLite database and WAL logs
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/internet-tracker 0755 root root -"
  ];

  # Impermanence persistence for Internet Tracker database
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/internet-tracker"
    ];
  };

  # Wait for Forgejo container registry login before starting container
  systemd.services."podman-internet-tracker" = {
    after = [ "podman-registry-login.service" ];
    wants = [ "podman-registry-login.service" ];
  };
}
