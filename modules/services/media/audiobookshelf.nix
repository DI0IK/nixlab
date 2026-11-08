{ ... }:

{
  services.audiobookshelf = {
    enable = true;
    port = 13378;
    host = "127.0.0.1";
    group = "media";
  };

  # Ensure Audiobookshelf user belongs to the shared media group
  users.users.audiobookshelf.extraGroups = [ "media" ];

  # Order service startup after external NFS media mount
  systemd.services.audiobookshelf = {
    after = [ "data-media.mount" ];
    wants = [ "data-media.mount" ];
  };

  # Impermanence persistence for Audiobookshelf database, metadata, and settings
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/audiobookshelf"
    ];
  };
}
