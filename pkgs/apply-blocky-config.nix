{
  lib,
  writeShellApplication,
  blocky,
}:
writeShellApplication {
  name = "apply-blocky-config";
  meta.description = "Validate Blocky configuration and refresh allow/deny lists";
  text = ''
    if (( $# != 0 )); then
      printf 'Usage: apply-blocky-config\n' >&2
      exit 1
    fi

    ${lib.getExe blocky} -c /etc/blocky validate
    ${lib.getExe blocky} -c /etc/blocky lists refresh
  '';
}
