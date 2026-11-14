{
  lib,
  lanchpadPackage,
  ...
}: {
  systemd.services.lanchpad = {
    description = "Lanchpad Discord bot";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    unitConfig.ConditionPathExists = "/var/lib/secrets/lanchpad.env";

    serviceConfig = {
      ExecStart = lib.getExe lanchpadPackage;
      EnvironmentFile = "/var/lib/secrets/lanchpad.env";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = "15s";
      KillSignal = "SIGINT";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
