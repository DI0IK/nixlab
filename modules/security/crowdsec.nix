{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.crowdsec = {
    enable = true;
    autoUpdateService = true;

    hub = {
      collections = [
        "crowdsecurity/linux"
        "crowdsecurity/traefik"
        "crowdsecurity/sshd"
        "crowdsecurity/http-cve"
        "crowdsecurity/whitelist-good-actors"
      ];
    };

    settings = {
      config = {
        api.server = {
          enable = true;
          # sabnzbd occupies port 8080, so run CrowdSec LAPI on port 8089
          listen_uri = "127.0.0.1:8089";
          online_client.credentials_path = "/etc/crowdsec/online_api_credentials.yaml";
        };
        api.client.credentials_path = "/etc/crowdsec/local_api_credentials.yaml";
      };

      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=traefik.service" ];
          labels.type = "syslog";
        }
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
      ];
    };
  };

  # Static crowdsec user/group definition for persistence, bouncer service, and traefik group membership
  users.users.crowdsec = {
    isSystemUser = true;
    group = "crowdsec";
    description = "CrowdSec service user";
    extraGroups = [ "systemd-journal" ];
  };
  users.groups.crowdsec = { };

  # Traefik user belongs to group crowdsec to read the bouncer API key
  users.users.traefik.extraGroups = [ "crowdsec" ];

  # Disable DynamicUser so CrowdSec uses the static user/group and /var/lib/crowdsec directly
  systemd.services = {
    crowdsec.serviceConfig.DynamicUser = lib.mkForce false;
    crowdsec-setup.serviceConfig.DynamicUser = lib.mkForce false;
    crowdsec-update-hub.serviceConfig.DynamicUser = lib.mkForce false;
  };

  # Provide a direct cscli wrapper so running cscli doesn't invoke systemd-run with DynamicUser
  environment.systemPackages = [
    (lib.hiPrio (
      pkgs.writeShellScriptBin "cscli" ''
        if [ "$USER" = "crowdsec" ] || [ "$(id -u)" -eq 0 ]; then
          exec ${lib.getExe' pkgs.crowdsec "cscli"} -c /etc/crowdsec/config.yaml "$@"
        else
          exec sudo -u crowdsec ${lib.getExe' pkgs.crowdsec "cscli"} -c /etc/crowdsec/config.yaml "$@"
        fi
      ''
    ))
  ];

  # Dedicated oneshot service to provision the bouncer key for Traefik
  systemd.services.crowdsec-traefik-bouncer = {
    description = "Provision Traefik Bouncer in CrowdSec";
    wantedBy = [ "multi-user.target" ];
    after = [ "crowdsec.service" ];
    requires = [ "crowdsec.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "crowdsec";
      Group = "crowdsec";
    };
    path = [
      pkgs.crowdsec
      pkgs.openssl
      pkgs.gnugrep
      pkgs.coreutils
    ];
    script = ''
      set -euo pipefail
      KEY_FILE="/var/lib/crowdsec/traefik-bouncer-key.txt"
      if [ ! -f "$KEY_FILE" ] || [ ! -s "$KEY_FILE" ]; then
        KEY=$(openssl rand -hex 32)
        echo -n "$KEY" > "$KEY_FILE"
        chmod 640 "$KEY_FILE"
      fi
      KEY=$(cat "$KEY_FILE")
      chmod 640 "$KEY_FILE"

      # Register bouncer with cscli if not already registered
      if ! cscli -c /etc/crowdsec/config.yaml bouncers list -o raw 2>/dev/null | grep -q "^traefik,"; then
        cscli -c /etc/crowdsec/config.yaml bouncers add traefik -k "$KEY"
      fi
    '';
  };

  # Persist CrowdSec database, hub, and configuration
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/var/lib/crowdsec";
        user = "crowdsec";
        group = "crowdsec";
        mode = "0750";
      }
      {
        directory = "/etc/crowdsec";
        user = "crowdsec";
        group = "crowdsec";
        mode = "0750";
      }
    ];
  };
}
