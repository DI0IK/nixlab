{
  config,
  pkgs,
  lib,
  ...
}:

let
  format = pkgs.formats.yaml { };
  crowdsecConfigFile = format.generate "crowdsec.yaml" config.services.crowdsec.settings.general;
in
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
      general = {
        api.server = {
          enable = true;
          # sabnzbd occupies port 8080, so run CrowdSec LAPI on port 8089
          listen_uri = "127.0.0.1:8089";
        };
      };
      lapi.credentialsFile = "/etc/crowdsec/local_api_credentials.yaml";
      capi.credentialsFile = "/etc/crowdsec/online_api_credentials.yaml";
    };

    localConfig = {
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

  # Expose crowdsec config file at standard /etc/crowdsec/config.yaml for cscli commands
  environment.etc."crowdsec/config.yaml".source = crowdsecConfigFile;

  # Traefik user belongs to group crowdsec to read the bouncer API key
  users.users.traefik.extraGroups = [ "crowdsec" ];

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
      if ! cscli -c ${crowdsecConfigFile} bouncers list -o raw 2>/dev/null | grep -q "^traefik,"; then
        cscli -c ${crowdsecConfigFile} bouncers add traefik -k "$KEY"
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
