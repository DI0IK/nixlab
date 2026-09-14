{ ... }:

{
  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = false;

    # Local LAN administration, DNS, MQTT, and Modbus proxy
    allowedTCPPorts = [
      22 # SSH
      53 # AdGuard Home DNS
      503 # Modbus proxy (Sungrow inverter telemetry)
      853 # AdGuard Home DNS-over-TLS (DoT)
      1883 # Mosquitto MQTT broker
    ];
    allowedUDPPorts = [
      53 # AdGuard Home DNS
      853 # AdGuard Home DNS-over-QUIC (DoQ)
    ];

    # Public web traffic and DNS over WireGuard VPS tunnel
    interfaces."wg-vps" = {
      allowedTCPPorts = [
        80 # HTTP (redirects to HTTPS)
        443 # HTTPS (Traefik)
        853 # AdGuard Home DNS-over-TLS (DoT)
        2222 # Forgejo SSH via WireGuard VPS tunnel
      ];
      allowedUDPPorts = [
        53 # AdGuard Home DNS
        853 # AdGuard Home DNS-over-QUIC (DoQ)
      ];
    };
  };
}
