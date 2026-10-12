{
  pkgs,
  manifest,
  allowlistFile,
  denylistFile,
}:
pkgs.runCommand "layat-home-pi-check" {
  nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.git pkgs.python3];
  exportReferencesGraph = ["manifest-closure" manifest];
  BLOCKY_MANIFEST = manifest;
  EXPECTED_ALLOWLIST = builtins.readFile allowlistFile;
  EXPECTED_DENYLIST = builtins.readFile denylistFile;
} ''
  python ${./check.py} ${./apply.sh}
  touch "$out"
''
