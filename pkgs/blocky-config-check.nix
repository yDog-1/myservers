{
  lib,
  runCommand,
  blocky,
  configFile,
}:
runCommand "check-blocky-config" {} ''
  ${lib.getExe blocky} --config ${configFile} validate
  touch "$out"
''
