{
  pkgs,
  homePi,
}:
pkgs.writeShellApplication {
  name = "layat-home-pi";
  meta.description = "Transfer and apply home-pi Blocky lists over SSH";
  runtimeInputs = [pkgs.coreutils pkgs.git pkgs.nix pkgs.openssh];
  runtimeEnv = {
    HOME_PI_LOCAL_SYSTEM = pkgs.stdenv.hostPlatform.system;
    HOME_PI_SSH_TARGET = "${homePi.deployUserName}@${homePi.ipAddress}";
  };
  text = builtins.readFile ./apply.sh;
}
