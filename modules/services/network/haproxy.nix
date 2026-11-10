{ pkgs, ... }:

{
  services.haproxy = {
    enable = true;
    config = ''
      global
        log /dev/log local0
        log /dev/log local1 notice
        maxconn 4096
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

      defaults
        log global
        mode tcp
        option tcplog
        timeout connect 5s
        timeout client 3600s
        timeout server 3600s

      # --- HTTP (Port 80) ---
      frontend ft_http
        bind *:80
        bind :::80 v4v6
        default_backend bk_http

      backend bk_http
        mode tcp
        server backend_http 172.30.32.2:80 send-proxy-v2

      # --- HTTPS (Port 443 with SNI Inspection) ---
      frontend ft_https
        bind *:443
        bind :::443 v4v6
        mode tcp
        tcp-request inspect-delay 5s
        tcp-request content accept if { req_ssl_hello_type 1 }

        # Route VPS services locally without tunnel roundtrips
        use_backend bk_vps_local if { req_ssl_sni -i status.dominikstahl.dev ntfy.dominikstahl.dev }

        # Forward all other homelab domains directly to homelab Traefik
        default_backend bk_homelab_https

      backend bk_homelab_https
        mode tcp
        server backend_https 172.30.32.2:443 send-proxy-v2 check

      backend bk_vps_local
        mode tcp
        server loopback 127.0.0.1:8443

      # --- Local HTTPS Termination for VPS Services ---
      frontend ft_vps_services
        bind 127.0.0.1:8443 ssl crt /var/lib/acme/vps-services/full.pem
        mode http
        option forwardfor
        use_backend bk_gatus if { hdr(host) -i status.dominikstahl.dev }
        use_backend bk_ntfy if { hdr(host) -i ntfy.dominikstahl.dev }

      backend bk_gatus
        mode http
        server gatus 127.0.0.1:8080

      backend bk_ntfy
        mode http
        server ntfy 127.0.0.1:2586

      # --- Forgejo Git SSH (Port 22) ---
      frontend ft_sftp
        bind *:22
        bind :::22 v4v6
        default_backend bk_sftp
        option clitcpka

      backend bk_sftp
        mode tcp
        timeout client 24h
        timeout server 24h
        option clitcpka
        option srvtcpka
        server backend_sftp 172.30.32.2:2222

      # --- DNS-over-TLS (Port 853) ---
      frontend ft_dot
        bind *:853
        bind :::853 v4v6
        default_backend bk_dot

      backend bk_dot
        mode tcp
        server backend_dot 172.30.32.2:853
    '';
  };

  # Bootstrap certificate if ACME has not obtained one yet
  systemd.services.haproxy = {
    wants = [ "acme-vps-services.service" ];
    after = [ "acme-vps-services.service" ];
    preStart = ''
      CERT_DIR="/var/lib/acme/vps-services"
      if [ ! -f "$CERT_DIR/full.pem" ]; then
        mkdir -p "$CERT_DIR"
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
          -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/fullchain.pem" \
          -days 1 -subj "/CN=status.dominikstahl.dev"
        cat "$CERT_DIR/fullchain.pem" "$CERT_DIR/key.pem" > "$CERT_DIR/full.pem"
        chown -R acme:certs "$CERT_DIR"
        chmod 750 "$CERT_DIR"
        chmod 640 "$CERT_DIR"/*
      fi
    '';
  };
}
