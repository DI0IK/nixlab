{
  config,
  pkgs,
  lib,
  ...
}:

let
  kiwixSync = pkgs.writeShellScriptBin "kiwix-sync" ''
    set -euo pipefail
    LIB="/var/lib/kiwix/library.xml"
    ZIM_DIR="/data/media/media/zim"

    mkdir -p /var/lib/kiwix
    if [ ! -f "$LIB" ]; then
      echo '<?xml version="1.0" encoding="UTF-8"?><library version="20110515"></library>' > "$LIB"
      chmod 644 "$LIB"
    fi

    if [ -d "$ZIM_DIR" ]; then
      mapfile -t zims < <(find "$ZIM_DIR" -type f -name "*.zim" | sort)
      if [ ''${#zims[@]} -gt 0 ]; then
        echo "Updating Kiwix library with ''${#zims[@]} ZIM archive(s)..."
        ${pkgs.kiwix-tools}/bin/kiwix-manage "$LIB" add "''${zims[@]}"
        echo "Library updated successfully."
      else
        echo "No .zim files found in $ZIM_DIR (searched recursively)."
      fi
    else
      echo "Directory $ZIM_DIR does not exist."
    fi
  '';
in
{
  # Dedicated system user and group for Kiwix
  users.users.kiwix = {
    isSystemUser = true;
    group = "kiwix";
    extraGroups = [ "media" ];
  };
  users.groups.kiwix = { };

  # Declarative directory creation on the media mount and state directory
  systemd.tmpfiles.rules = [
    "d /data/media/media/zim 0775 root media -"
    "d /persist/var/lib/kiwix 0755 kiwix kiwix -"
  ];

  # Kiwix ZIM archive HTTP server
  services.kiwix-serve = {
    enable = true;
    address = "127.0.0.1";
    port = 8095;
    libraryPath = "/var/lib/kiwix/library.xml";
    extraArgs = [
      "--monitorLibrary"
      "--searchLimit=100"
    ];
  };

  # Systemd service configuration and dependencies
  systemd.services.kiwix-serve = {
    after = [ "data-media.mount" ];
    wants = [ "data-media.mount" ];

    preStart = ''
      # Ensure state directory exists and initialize XML library if missing
      mkdir -p /var/lib/kiwix
      if [ ! -f /var/lib/kiwix/library.xml ]; then
        echo '<?xml version="1.0" encoding="UTF-8"?><library version="20110515"></library>' > /var/lib/kiwix/library.xml
        chmod 644 /var/lib/kiwix/library.xml
      fi

      # Index existing ZIM archives recursively on startup if any exist
      if [ -d /data/media/media/zim ]; then
        mapfile -t zim_files < <(find /data/media/media/zim -type f -name "*.zim" | sort)
        if [ ''${#zim_files[@]} -gt 0 ]; then
          ${pkgs.kiwix-tools}/bin/kiwix-manage /var/lib/kiwix/library.xml add "''${zim_files[@]}" || true
        fi
      fi
    '';

    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "kiwix";
      Group = "kiwix";
      StateDirectory = "kiwix";
      StateDirectoryMode = "0755";
      PrivateUsers = lib.mkForce false;
      UMask = lib.mkForce "0022";
      ReadOnlyPaths = [ "/data/media/media/zim" ];
      SupplementaryGroups = [ "media" ];
    };
  };

  # System utility to resync Kiwix library on demand
  environment.systemPackages = [
    kiwixSync
    pkgs.kiwix-tools
  ];

  # Impermanence persistence for Kiwix library index
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/kiwix"
    ];
  };
}
