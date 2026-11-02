{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    netronome = {
      image = "ghcr.io/autobrr/netronome:v0.16.0";
      autoStart = true;
      user = "0";
      extraOptions = [
        # Network host mode allows accurate bare-metal bandwidth measurements and low-overhead raw sockets for ICMP/mtr/traceroute
        "--network=host"
      ];
      environment = {
        NETRONOME__HOST = "127.0.0.1";
        NETRONOME__PORT = "7575";
        NETRONOME__BASE_URL = "/";

        # Trust Traefik reverse proxy headers for real client IPs and secure HTTPS cookies
        NETRONOME__AUTH_TRUSTED_PROXIES = "127.0.0.1/32,::1/128";

        # OpenID Connect (Authentik SSO)
        NETRONOME__OIDC_ISSUER = "https://sso.${config.networking.domain}/application/o/netronome/";
        NETRONOME__OIDC_CLIENT_ID = "8QKYMMikUQeDotT6dzlZ34mBD3McVFZqdahaJW2r";
        NETRONOME__OIDC_REDIRECT_URL = "https://netronome.${config.networking.domain}/api/auth/oidc/callback";
        NETRONOME__OIDC_SCOPES = "openid,profile,email,offline_access";
      };
      environmentFiles = [
        config.sops.templates."netronome.env".path
      ];
      volumes = [
        "/persist/var/lib/netronome:/data"
      ];
    };
  };

  # Declarative directory creation for persistent database, config, and data
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/netronome 0755 root root -"
  ];

  # Impermanence persistence for Netronome SQLite database and configuration
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/netronome"
    ];
  };
}
