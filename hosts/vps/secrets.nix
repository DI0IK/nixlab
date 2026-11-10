{ config, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/vps.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "system-ssh-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "wg-private-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "admin-password-hash" = {
        neededForUsers = true;
      };

      "cloudflare-api-token" = {
        owner = "acme";
        group = "acme";
        mode = "0400";
      };
    };

    templates."acme-cf.env" = {
      content = ''
        CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
        CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
      '';
      owner = "acme";
      group = "acme";
      mode = "0400";
    };
  };
}
