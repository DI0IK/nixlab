{ pkgs, ... }:

{
  # Native host caching server using Valkey (open-source Redis fork)
  services.redis = {
    package = pkgs.valkey;

    servers."default" = {
      enable = true;
      bind = "127.0.0.1";
      port = 6379;
      save = [
        [
          900
          1
        ]
        [
          300
          10
        ]
        [
          60
          10000
        ]
      ];
    };
  };

  # Impermanence persistence for Valkey data
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/redis-default"
    ];
  };
}
