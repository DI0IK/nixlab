{ ... }:

{
  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = [ "wg0" ];
    forwardPorts = [
      {
        sourcePort = 2022;
        proto = "tcp";
        destination = "172.30.32.3:2022";
      }
      {
        sourcePort = 25565;
        proto = "tcp";
        destination = "172.30.32.3:25565";
      }
      {
        sourcePort = 25565;
        proto = "udp";
        destination = "172.30.32.3:25565";
      }
      {
        sourcePort = 7777;
        proto = "udp";
        destination = "172.30.32.3:7777";
      }
      {
        sourcePort = 34197;
        proto = "udp";
        destination = "172.30.32.3:34197";
      }
    ];

    extraCommands = ''
      # Valheim UDP game and query ports
      iptables -t nat -A PREROUTING -i eth0 -p udp --dport 2456:2457 -j DNAT --to-destination 172.30.32.3

      # Buffer allocations range
      iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 20000:20010 -j DNAT --to-destination 172.30.32.3
      iptables -t nat -A PREROUTING -i eth0 -p udp --dport 20000:20010 -j DNAT --to-destination 172.30.32.3

      # Dual-port WireGuard: OpenVPN default port (UDP 1194) redirected to WireGuard (51820)
      iptables -t nat -A PREROUTING -i eth0 -p udp --dport 1194 -j REDIRECT --to-ports 51820
      ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport 1194 -j REDIRECT --to-ports 51820

      # Forward traffic between WireGuard clients (so mobile clients can reach homelab directly)
      iptables -A FORWARD -i wg0 -o wg0 -j ACCEPT
      ip6tables -A FORWARD -i wg0 -o wg0 -j ACCEPT

      # MSS clamping for WireGuard MTU 1350
      iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o wg0 -j TCPMSS --clamp-mss-to-pmtu
    '';
  };

  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = false;

    allowedTCPPorts = [
      22 # Forgejo Git SSH forwarded to homelab
      80 # Public HTTP
      443 # Public HTTPS
      853 # AdGuard DNS-over-TLS forwarded to homelab
      2022 # Calagopus SFTP forwarded to Wings
      22222 # Host OpenSSH management port
      25565 # Minecraft Java forwarded to Wings
    ];

    allowedTCPPortRanges = [
      {
        from = 20000;
        to = 20010;
      }
    ];

    allowedUDPPorts = [
      53 # AdGuard DNS forwarded to homelab
      853 # AdGuard DNS-over-QUIC forwarded to homelab
      1194 # OpenVPN port for WireGuard connection on restricted networks
      7777 # Satisfactory forwarded to Wings
      25565 # Minecraft Bedrock/UDP forwarded to Wings
      34197 # Factorio forwarded to Wings
      51820 # Native WireGuard port
    ];

    allowedUDPPortRanges = [
      {
        from = 2456;
        to = 2457;
      }
      {
        from = 20000;
        to = 20010;
      }
    ];
  };
}
