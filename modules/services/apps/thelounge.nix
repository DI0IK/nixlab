{ ... }:

{
  services.thelounge = {
    enable = true;
    port = 9001;
    extraConfig = {
      reverseProxy = true;
      host = "127.0.0.1";
    };
  };

  # Impermanence persistence for The Lounge user profiles, logs, and sessions
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/thelounge"
    ];
  };
}
