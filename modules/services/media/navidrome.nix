{ ... }:

{
  services.navidrome = {
    enable = true;
    group = "media";

    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "/data/media/media/music";
      ScanSchedule = "@every 1h";
      ListenBrainz = {
        BaseURL = "http://127.0.0.1:9078/1/";
      };
    };
  };

  systemd.services.navidrome = {
    after = [ "data-media.mount" ];
    wants = [ "data-media.mount" ];
  };

  # Impermanence persistence for Navidrome cache and database
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/navidrome"
    ];
  };
}
