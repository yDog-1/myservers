{
  config,
  lib,
  pkgs,
  ...
}: {
  services.resolved.enable = false;
  networking.nameservers = ["127.0.0.1"];

  # Keep DNS reachable from both LAN and Tailscale.
  networking.firewall = {
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };

  services.blocky = {
    enable = true;
    # The upstream check validates settings-generated YAML; use our file instead.
    enableConfigCheck = false;
  };

  environment.etc = {
    "blocky/config.yaml".source = ./blocky.yaml;
    "systemd/journald@blocky.conf".text = ''
      [Journal]
      Storage=persistent
      MaxRetentionSec=24h
      MaxFileSec=1h
      RateLimitIntervalSec=0
      ForwardToSyslog=no
      ForwardToKMsg=no
      ForwardToConsole=no
      ForwardToWall=no
    '';
  };

  systemd.services.blocky = {
    restartTriggers = [config.environment.etc."blocky/config.yaml".source];
    serviceConfig = {
      ExecStart = lib.mkForce "${lib.getExe config.services.blocky.package} --config /etc/blocky/config.yaml";
      LogNamespace = "blocky";
    };
  };

  systemd.services."systemd-journald@blocky" = {
    # Preserve the upstream template's ExecStart and sandboxing.
    overrideStrategy = "asDropin";
    restartTriggers = [config.environment.etc."systemd/journald@blocky.conf".source];
    stopIfChanged = false;
  };

  # Vacuum even when there are no new queries; archived files are removed as units.
  systemd.services.blocky-journal-cleanup = {
    description = "Rotate and expire Blocky logs older than about one day";
    requires = ["systemd-journald@blocky.service"];
    after = ["systemd-journald@blocky.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/journalctl --namespace=blocky --rotate --vacuum-time=1d";
    };
  };

  systemd.timers.blocky-journal-cleanup = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  system.checks = [
    (pkgs.callPackage ../../pkgs/blocky-config-check.nix {
      blocky = config.services.blocky.package;
      configFile = ./blocky.yaml;
    })
  ];
}
