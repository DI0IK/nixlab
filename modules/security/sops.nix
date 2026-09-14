{ config, ... }:

{
  sops = {
    # Path to encrypted secrets file (created from secrets/secrets.example.yaml)
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    # Decrypt using host Ed25519 key on persistent storage
    age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "wg-private-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "cloudflare-api-token" = {
        owner = "traefik";
        group = "traefik";
        mode = "0400";
      };

      "authentik-secret-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "borg-repo-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "system-ssh-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "storagebox-pass" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "immich-oauth-client-secret" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "authentik-outpost-token" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "searxng-secret-key" = {
        owner = "searx";
        group = "searx";
        mode = "0400";
      };

      "admin-password-hash" = {
        neededForUsers = true;
      };
    };

    templates = {

      "acme-cf.env" = {
        content = ''
          CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
          CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
          CLOUDFLARE_ZONE_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
          CF_ZONE_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
        '';
        owner = "acme";
        group = "acme";
        mode = "0400";
      };

      "authentik.env" = {
        content = ''
          AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik-secret-key"}
        '';
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "authentik-ldap.env" = {
        content = ''
          AUTHENTIK_TOKEN=${config.sops.placeholder."authentik-outpost-token"}
        '';
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "searxng.env" = {
        content = ''
          SEARXNG_SECRET_KEY=${config.sops.placeholder."searxng-secret-key"}
          SEARX_SECRET_KEY=${config.sops.placeholder."searxng-secret-key"}
        '';
        owner = "searx";
        group = "searx";
        mode = "0400";
      };

      "immich-config.yaml" = {
        content = ''
          machineLearning:
            clip:
              enabled: true
              modelName: "ViT-B-16-SigLIP2__webli"
            facialRecognition:
              enabled: true
              modelName: "buffalo_l"
              minScore: 0.7
              maxDistance: 0.3
              minFaces: 3
          trash:
            enabled: false
            days: 30
          storageTemplate:
            enabled: true
            template: "{{y}}/{{MM}}/{{dd}}/{{filename}}"
          oauth:
            autoLaunch: true
            autoRegister: true
            buttonText: "Login with Authentik"
            clientId: iPFX7ek90F00029l0XIxCiPyxGUZaiqvXu3HaI1k
            clientSecret: ${config.sops.placeholder."immich-oauth-client-secret"}
            defaultStorageQuota: 0
            enabled: true
            issuerUrl: https://sso.dominikstahl.dev/application/o/immich/
          passwordLogin:
            enabled: false
          server:
            externalDomain: https://photos.dominikstahl.dev
          ffmpeg:
            crf: 23
            threads: 0
            preset: "ultrafast"
            targetVideoCodec: "h264"
            acceptedVideoCodecs:
              - "h264"
            targetAudioCodec: "aac"
            acceptedAudioCodecs:
              - "aac"
              - "mp3"
              - "opus"
            acceptedContainers:
              - "mov"
              - "ogg"
              - "webm"
            targetResolution: "720"
            maxBitrate: "0"
            bframes: -1
            refs: 0
            gopSize: 0
            temporalAQ: false
            cqMode: "auto"
            twoPass: false
            preferredHwDevice: "auto"
            transcode: "required"
            tonemap: "hable"
            accel: "qsv"
            accelDecode: true
          job:
            backgroundTask:
              concurrency: 5
            smartSearch:
              concurrency: 4
            metadataExtraction:
              concurrency: 5
            faceDetection:
              concurrency: 3
            search:
              concurrency: 5
            sidecar:
              concurrency: 5
            library:
              concurrency: 5
            migration:
              concurrency: 5
            thumbnailGeneration:
              concurrency: 5
            videoConversion:
              concurrency: 1
            notifications:
              concurrency: 5
          library:
            scan:
              enabled: true
              cronExpression: "0 10 * * *"
            watch:
              enabled: false
        '';
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };
}
