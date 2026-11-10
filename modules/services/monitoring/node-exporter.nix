{ ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    listenAddress = "172.30.32.1";
    enabledCollectors = [
      "systemd"
      "diskstats"
      "cpu"
      "meminfo"
      "netdev"
    ];
  };
}
