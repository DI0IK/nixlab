{ ... }:

{
  virtualisation.oci-containers.containers = {
    roomfinder-api = {
      image = "git.dominikstahl.dev/dominik/roomfinder_api:v0.0.1";
      autoStart = true;
      ports = [
        "127.0.0.1:8025:8000"
      ];
      environment = {
        PORT = "8000";
      };
    };
  };
}
