{ pkgs, ... }:

{
  # Home Assistant Core
  services.home-assistant = {
    enable = true;
    configDir = "/var/lib/hass";

    # Leave configuration.yaml to be managed directly in /persist/var/lib/hass
    config = null;

    extraComponents = [
      "default_config"
      "met"
      "esphome"
      "mqtt"
      "radio_browser"
      "co2signal"
      "forecast_solar"
      "remote_calendar"
      "wyoming"
      "zha"
      "mobile_app"
      "sun"
      "template"
      "group"
      "analytics"
      "backup"
      "modbus"
      "prometheus"
    ];
  };

  # Local hostname mappings for Home Assistant service discovery
  networking.hosts = {
    "127.0.0.1" = [
      "mosquitto"
      "mosquitto.home-assistant.svc.cluster.local"
      "sungrow-modbus-proxy"
      "sungrow-modbus-proxy.home-assistant.svc.cluster.local"
    ];
  };

  # Allow Home Assistant access to Zigbee USB dongle (/dev/ttyUSB0)
  users.users.hass.extraGroups = [ "dialout" ];

  # Mosquitto MQTT broker
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        address = "0.0.0.0";
        port = 1883;
        settings.allow_anonymous = true;
      }
    ];
  };

  # Impermanence persistence for Home Assistant DB/storage and Mosquitto DB
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/hass"
      "/var/lib/mosquitto"
    ];
  };
}
