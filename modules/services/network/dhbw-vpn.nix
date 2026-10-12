{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.dhbw-vpn;

  forwardArgs = concatStringsSep " " (map (f: "-L ${f}") cfg.portForwards);

  ocproxyWrapper = pkgs.writeShellScript "dhbw-vpn-ocproxy" ''
    exec ${pkgs.ocproxy}/bin/ocproxy -D ${cfg.bindAddress}:${toString cfg.port} -g -k 30 ${forwardArgs} "$@"
  '';

  vpnScript = pkgs.writeShellScript "dhbw-vpn-start" ''
    set -euo pipefail

    USER_FILE="${config.sops.secrets."dhbw-vpn-username".path}"
    PASS_FILE="${config.sops.secrets."dhbw-vpn-password".path}"
    TOTP_FILE="${config.sops.secrets."dhbw-vpn-2fa-secret".path}"

    if [[ ! -f "$USER_FILE" || ! -f "$PASS_FILE" || ! -f "$TOTP_FILE" ]]; then
      echo "DHBW VPN secrets not found at expected paths." >&2
      exit 1
    fi

    USERNAME=$(tr -d '\r\n' < "$USER_FILE")
    PASSWORD=$(tr -d '\r\n' < "$PASS_FILE")
    TOTP_SECRET=$(tr -d ' \t\r\n' < "$TOTP_FILE" | tr '[:lower:]' '[:upper:]')

    if [[ -z "$USERNAME" || -z "$PASSWORD" || -z "$TOTP_SECRET" ]]; then
      echo "DHBW VPN credentials in SOPS are empty." >&2
      exit 1
    fi

    # Append @dh-karlsruhe.de domain if not already provided
    if [[ "$USERNAME" != *"@"* ]]; then
      USERNAME="''${USERNAME}@dh-karlsruhe.de"
    fi

    # Generate current 6-digit TOTP code
    OTP=$(${pkgs.oath-toolkit}/bin/oathtool --totp -b "$TOTP_SECRET")

    # DHBW Lehre-VPN requires password + 6-digit TOTP concatenated
    FULL_PASS="''${PASSWORD}''${OTP}"

    echo "Authenticating to vpn.dh-karlsruhe.de for $USERNAME..."

    exec ${pkgs.openconnect}/bin/openconnect \
      --protocol=anyconnect \
      --non-inter \
      --queue-len=1 \
      --user="$USERNAME" \
      --passwd-on-stdin \
      --script-tun \
      --script="${ocproxyWrapper}" \
      https://vpn.dh-karlsruhe.de <<< "$FULL_PASS"
  '';

  # Extract local port numbers from 'local_port:remote_host:remote_port'
  forwardPorts = map (
    entry:
    let
      parts = splitString ":" entry;
    in
    toInt (head parts)
  ) cfg.portForwards;
in
{
  options.services.dhbw-vpn = {
    enable = mkEnableOption "DHBW Karlsruhe AnyConnect VPN SOCKS5 proxy via openconnect and ocproxy";

    port = mkOption {
      type = types.port;
      default = 1080;
      description = "Port on which the SOCKS5 proxy listens.";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address to bind the SOCKS5 proxy to.";
    };

    portForwards = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "2201:db1.inf.dh-karlsruhe.de:22"
        "2202:db2.inf.dh-karlsruhe.de:22"
      ];
      description = "List of local port forwardings in format 'local_port:remote_host:remote_port'. Ideal for Guacamole and other applications that do not natively speak SOCKS5.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.dhbw-vpn = {
      description = "DHBW Karlsruhe AnyConnect VPN SOCKS5 Proxy";
      after = [
        "network-online.target"
        "sops-nix.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${vpnScript}";
        Restart = "always";
        RestartSec = "15s";

        # Sandboxing
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    # Allow local container and LAN access to the SOCKS proxy and forwarded ports
    networking.firewall.interfaces."podman0".allowedTCPPorts = [ cfg.port ] ++ forwardPorts;
    networking.firewall.interfaces."eno1".allowedTCPPorts = [ cfg.port ] ++ forwardPorts;
  };
}
