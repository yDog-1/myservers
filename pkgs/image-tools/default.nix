{
  pkgs,
  imageDrv,
  nixConfig,
}: {
  export-home-pi-image = pkgs.writeShellApplication {
    name = "export-home-pi-image";
    meta.description = "Build and export the home-pi SD image with its SHA-256 checksum";
    runtimeInputs = [pkgs.coreutils pkgs.nix pkgs.zstd];
    runtimeEnv = {
      HOME_PI_IMAGE_DRV = imageDrv;
      HOME_PI_SUBSTITUTERS = builtins.concatStringsSep " " nixConfig.extra-substituters;
      HOME_PI_PUBLIC_KEYS = builtins.concatStringsSep " " nixConfig.extra-trusted-public-keys;
    };
    text = builtins.readFile ./export.sh;
  };
} // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  flash-home-pi-image = pkgs.writeShellApplication {
    name = "flash-home-pi-image";
    meta.description = "Write and verify a home-pi image on an explicitly selected SD card";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux pkgs.jq];
    text = builtins.readFile ./flash.sh;
  };
}
