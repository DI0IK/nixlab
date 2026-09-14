{ ... }:

{
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd"
    ];

    files = [
      "/etc/machine-id"
    ];
  };
}
