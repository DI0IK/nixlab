{ ... }:

{
  services.cut-rs = {
    enable = true;
    host = "127.0.0.1";
    port = 8090;
    trustProxyHeaders = true;
    # Optional: point to a sops-nix secret file containing HMAC_SECRET=...
    # environmentFile = config.sops.secrets."cut-rs/env".path;
  };

  # Impermanence persistence for cut-rs SQLite database
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/var/lib/cut-rs";
        user = "cut-rs";
        group = "cut-rs";
        mode = "0750";
      }
    ];
  };
}
