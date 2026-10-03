{ ... }:

{
  # Host-side directory preparation for MicroVM storage (with Btrfs NoCoW)
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/microvms 0775 microvm kvm -"
    "h /persist/var/lib/microvms - - - - +C"
  ];

  # Host-side network bridge for MicroVM communication
  networking.bridges.br-microvm.interfaces = [ ];
  networking.interfaces.br-microvm.ipv4.addresses = [
    {
      address = "10.100.0.1";
      prefixLength = 24;
    }
  ];

  # Allow local traffic between host and trusted MicroVMs (e.g. Calagopus Wings)
  networking.firewall.trustedInterfaces = [ "br-microvm" ];

  # NAT outbound traffic so MicroVMs have internet access
  networking.nat = {
    enable = true;
    internalInterfaces = [ "br-microvm" ];
  };

  # Impermanence: ensure MicroVM state and virtual disks persist across host reboots
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/microvms"
    ];
  };

  # Strict firewall isolation for untrusted CI runners on br-microvm (10.100.0.30)
  # Prepend rules at the very top of INPUT and FORWARD chains:
  networking.firewall.extraCommands = ''
    # 1. Block CI runner from communicating with the host itself
    iptables -I INPUT 1 -i br-microvm -s 10.100.0.30 -j DROP

    # 2. Block CI runner from accessing any RFC1918 / private / internal subnets
    iptables -I FORWARD 1 -i br-microvm -s 10.100.0.30 -d 10.0.0.0/8 -j DROP
    iptables -I FORWARD 2 -i br-microvm -s 10.100.0.30 -d 172.16.0.0/12 -j DROP
    iptables -I FORWARD 3 -i br-microvm -s 10.100.0.30 -d 192.168.0.0/16 -j DROP
    iptables -I FORWARD 4 -i br-microvm -s 10.100.0.30 -d 100.64.0.0/10 -j DROP
    iptables -I FORWARD 5 -i br-microvm -s 10.100.0.30 -d 169.254.0.0/16 -j DROP
    iptables -I FORWARD 6 -i br-microvm -s 10.100.0.30 -d 127.0.0.0/8 -j DROP
  '';
}
