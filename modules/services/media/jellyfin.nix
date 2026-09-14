{ pkgs, ... }:

{
  # Jellyfin media server
  services.jellyfin = {
    enable = true;

    package = pkgs.jellyfin;
  };

  systemd.services.jellyfin = {
    environment = {
      LIBVA_DRIVER_NAME = "iHD";
      LIBVA_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
      OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
      LD_LIBRARY_PATH = "/run/opengl-driver/lib:${pkgs.ocl-icd}/lib";
    };
    serviceConfig = {
      DeviceAllow = [
        "/dev/dri/renderD128 rw"
        "/dev/dri/card0 rw"
      ];
      PrivateDevices = false;
      SupplementaryGroups = [ "video" "render" ];
    };
  };

  # Grant Jellyfin access to Intel QuickSync VA-API render nodes
  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];

  # Jellyseerr / Seerr request management system
  services.seerr = {
    enable = true;
    package = pkgs.seerr;
    port = 5055;
    stateRevision = 1;
  };

  # Impermanence persistence for media server metadata, transcode cache, and configs
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/jellyfin"
      "/var/lib/private/seerr"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /dev/shm/jellyfin-transcode 0770 jellyfin jellyfin -"
  ];
}
