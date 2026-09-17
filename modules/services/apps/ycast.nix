{ pkgs, ... }:

let
  stationsConfig = pkgs.writeText "stations.yml" ''
    My Favorites:
      RPR1: "http://stream.rpr1.de/ludwigshafen/mp3-128/private"
      SWR3: "http://swr-swr3-live.cast.addradio.de/swr/swr3/live/mp3/128/stream.mp3"
  '';

  ycast = pkgs.python3Packages.buildPythonPackage rec {
    pname = "ycast";
    version = "1.1.0";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "milaq";
      repo = "YCast";
      rev = version;
      hash = "sha256-KMwKiQgWfNjBQ7F1gG+DRYQ9XfH4tkS+qZgd6SMaoOs=";
    };

    build-system = with pkgs.python3Packages; [
      setuptools
    ];

    dependencies = with pkgs.python3Packages; [
      flask
      requests
      pyyaml
      pillow
    ];

    doCheck = false;
  };
in
{
  systemd.services.ycast = {
    description = "YCast vTuner Emulator";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.python3.withPackages (_: [ ycast ])}/bin/python3 -m ycast -l 127.0.0.1 -p 8010 -c ${stationsConfig}";
      Restart = "on-failure";
      RestartSec = "5s";

      DynamicUser = true;

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
