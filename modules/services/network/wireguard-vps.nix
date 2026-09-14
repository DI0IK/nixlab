{ config, ... }:

{
  networking.wg-quick.interfaces.wg-vps = {
    autostart = true;
    address = [
      "172.30.32.2/24"
      "fd86:ea04:1115::2/128"
    ];
    mtu = 1350;
    privateKeyFile = config.sops.secrets."wg-private-key".path;

    peers = [
      {
        publicKey = "xp2zUi4Dx1wSQwZq3mKL7RwOIKFc9G12LyzinAj/8C4=";
        endpoint = "217.154.87.4:51820";
        allowedIPs = [
          "172.30.32.1/24"
          "fd86:ea04:1115::1/128"
        ];
        persistentKeepalive = 20;
      }
    ];
  };
}
