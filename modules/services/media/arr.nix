{ ... }:

{
  # Shared media group for cross-service library permissions
  users.groups.media = { };

  # Radarr (Movies)
  services.radarr = {
    enable = true;
    group = "media";
  };

  # Sonarr (TV Series)
  services.sonarr = {
    enable = true;
    group = "media";
  };

  # Prowlarr (Indexer Proxy)
  services.prowlarr = {
    enable = true;
  };

  # Bazarr (Subtitles)
  services.bazarr = {
    enable = true;
    group = "media";
  };

  # Lidarr (Music)
  services.lidarr = {
    enable = true;
    group = "media";
  };

  # SABnzbd (Usenet Downloader)
  services.sabnzbd = {
    enable = true;
    group = "media";
  };

  # Grant Jellyfin access to the shared media group
  users.users.jellyfin.extraGroups = [ "media" ];

  # Impermanence persistence for Arr configurations and databases
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/radarr"
      "/var/lib/sonarr"
      "/var/lib/private/prowlarr"
      "/var/lib/bazarr"
      "/var/lib/lidarr"
      "/var/lib/sabnzbd"
    ];
  };
}
