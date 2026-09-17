{ config, pkgs, ... }:

{
  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    port = 28010;
    domain = "paperless.dominikstahl.dev";
    configureTika = true;

    dataDir = "/var/lib/paperless";
    mediaDir = "/var/lib/paperless/media";
    consumptionDir = "/var/lib/paperless/consume";
    consumptionDirIsPublic = true;

    passwordFile = config.sops.secrets."paperless-admin-password".path;

    exporter = {
      enable = true;
      directory = "/var/backup/paperless-export";
      onCalendar = "03:30:00";
      settings = {
        zip = true;
      };
    };

    environmentFile = config.sops.templates."paperless-env".path;

    settings = {
      PAPERLESS_DBENGINE = "postgresql";
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_DBNAME = "paperless";
      PAPERLESS_DBUSER = "paperless";

      PAPERLESS_TIME_ZONE = "Europe/Berlin";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
        optimize = 1;
        unpaper_args = "--clean";
      };

      PAPERLESS_TRUSTED_PROXIES = "127.0.0.1";

      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      PAPERLESS_SOCIALACCOUNT_AUTOMATIC_REDIRECT = "true";
    };

    openMPThreadingWorkaround = true;
  };

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/paperless"
      "/var/backup/paperless-export"
    ];
  };
}
