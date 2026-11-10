{ ... }:

{
  # Gatus automated uptime monitoring and health checks
  services.gatus = {
    enable = true;
    settings = {
      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      endpoints = [
        # 1. WireGuard Tunnel to Homelab
        {
          name = "Homelab WireGuard Ping";
          group = "Infrastructure";
          url = "icmp://172.30.32.2";
          interval = "30s";
          conditions = [ "[CONNECTED] == true" ];
          alerts = [
            {
              type = "ntfy";
              enabled = true;
              send-on-resolved = true;
              failure-threshold = 2;
            }
          ];
        }

        # 2. WireGuard Tunnel to Calagopus Games Wing
        {
          name = "Calagopus Wings Ping";
          group = "Infrastructure";
          url = "icmp://172.30.32.3";
          interval = "30s";
          conditions = [ "[CONNECTED] == true" ];
          alerts = [
            {
              type = "ntfy";
              enabled = true;
              send-on-resolved = true;
              failure-threshold = 2;
            }
          ];
        }

        # 3. Public Web Ingress - Forgejo Git
        {
          name = "Forgejo Git";
          group = "Core Services";
          url = "https://git.dominikstahl.dev";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [
            {
              type = "ntfy";
              enabled = true;
              send-on-resolved = true;
              failure-threshold = 2;
            }
          ];
        }

        # 4. Public Web Ingress - Authentik SSO
        {
          name = "Authentik SSO";
          group = "Core Services";
          url = "https://sso.dominikstahl.dev";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [
            {
              type = "ntfy";
              enabled = true;
              send-on-resolved = true;
              failure-threshold = 2;
            }
          ];
        }

        # 5. Public Web Ingress - Homelab Dashboard (behind Authentik forwardAuth)
        {
          name = "Homelab Dashboard";
          group = "Core Services";
          url = "https://home.dominikstahl.dev";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [
            {
              type = "ntfy";
              enabled = true;
              send-on-resolved = true;
              failure-threshold = 2;
            }
          ];
        }

        # 6. AdGuard DNS over TLS (via WireGuard)
        {
          name = "DNS-over-TLS (Homelab)";
          group = "Network";
          url = "tcp://172.30.32.2:853";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
          alerts = [
            {
              type = "ntfy";
              enabled = true;
              send-on-resolved = true;
              failure-threshold = 2;
            }
          ];
        }
      ];

      alerting = {
        ntfy = {
          url = "http://127.0.0.1:2586";
          topic = "homelab-alerts";
          click = "https://status.dominikstahl.dev";
          priority = 4;
        };
      };
    };
  };

  # Ensure state directory exists for Gatus SQLite database
  systemd.services.gatus.serviceConfig = {
    StateDirectory = "gatus";
  };

  # Impermanence persistence for Gatus uptime history and SQLite database
  environment.persistence."/persist".directories = [
    "/var/lib/gatus"
  ];
}
