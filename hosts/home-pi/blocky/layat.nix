{pkgs, layatLib}:
layatLib.mkManifest {
  inherit pkgs;
  root = "/etc/blocky";
  entries = {
    # Derivations retain string context through layat's `toString src`, so the
    # lists are real closure dependencies for nix copy and profile GC roots.
    "allowlist.txt".src = pkgs.writeText "home-pi-blocky-allowlist.txt" (builtins.readFile ./allowlist.txt);
    "denylist.txt".src = pkgs.writeText "home-pi-blocky-denylist.txt" (builtins.readFile ./denylist.txt);
  };
}
