{ config, ... }:

{
  networking.wg-quick.interfaces.wg0 = {
    autostart = true;
    address = [
      "172.30.32.1/24"
      "fd86:ea04:1115::1/64"
    ];
    listenPort = 51820;
    mtu = 1350;
    privateKeyFile = config.sops.secrets."wg-private-key".path;

    peers = [
      # NixOS Homelab
      {
        publicKey = "qLaTQ1iwBi5esETUZLbL+KS3VDd7eNBJon9TC9FmmSQ=";
        allowedIPs = [
          "172.30.32.2/32"
          "fd86:ea04:1115::2/128"
        ];
      }

      # NixOS Games Wing (Calagopus)
      {
        publicKey = "vp02V/beFZWQXdjCRwfB0W6d0gvn6H9iwPVZT9ky8iM=";
        allowedIPs = [
          "172.30.32.3/32"
          "fd86:ea04:1115::3/128"
        ];
      }

      # Laptop
      {
        publicKey = "kpnkddOAO9MrErxZf1h/6ds0v/1pKQ035aJa8173zQ8=";
        allowedIPs = [
          "172.30.32.20/32"
          "fd86:ea04:1115::20/128"
        ];
        persistentKeepalive = 25;
      }

      # Handy (Phone)
      {
        publicKey = "lPoEmiOPos1zlFZcASZH6kL+uHQCYXKbg0xM7bkRdD0=";
        allowedIPs = [
          "172.30.32.10/32"
          "fd86:ea04:1115::10/128"
        ];
        persistentKeepalive = 25;
      }

      # Tablet
      {
        publicKey = "Rod3l9yHpzSh8GKcPblv854r8l6TVy+i7FspuawwIVY=";
        allowedIPs = [
          "172.30.32.11/32"
          "fd86:ea04:1115::11/128"
        ];
        persistentKeepalive = 25;
      }
    ];
  };
}
