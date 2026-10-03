{pkgs}: pkgs.runCommand "home-pi-image-tools-check" {
  nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.zstd];
} ''
  export HOME_PI_IMAGE_DRV=/unused/image.drv
  export HOME_PI_SUBSTITUTERS=https://cache.example.invalid
  export HOME_PI_PUBLIC_KEYS=unused
  export FAKE_NIX_LOG="$PWD/nix-called"
  mkdir -p mock-bin fixture/sd-image default-output compressed/sd-image custom-output
  export FAKE_IMAGE_DIR="$PWD/fixture"
  cat > mock-bin/nix <<'EOF'
  #!${pkgs.bash}/bin/bash
  touch "$FAKE_NIX_LOG"
  printf '%s\n' "$FAKE_IMAGE_DIR"
  EOF
  cat > mock-bin/sudo <<'EOF'
  #!${pkgs.bash}/bin/bash
  echo 'Tests must never invoke sudo' >&2
  exit 99
  EOF
  chmod +x mock-bin/*
  export PATH="$PWD/mock-bin:$PATH"
  exporter() { bash -euo pipefail ${./export.sh} "$@"; }
  flasher() { bash -euo pipefail ${./flash.sh} "$@"; }
  expectFailure() {
    local message=$1
    shift
    if "$@" > failure.log 2>&1; then
      echo "Unexpected success: $*" >&2
      exit 1
    fi
    grep -F -- "$message" failure.log
  }

  exporter --help
  flasher --help
  test ! -e "$FAKE_NIX_LOG"
  expectFailure 'requires a path' exporter --output
  expectFailure 'requires a path' flasher --input
  expectFailure 'Usage:' flasher
  expectFailure 'Exactly one device' flasher /dev/first /dev/second
  expectFailure 'Unknown option' flasher --device /dev/first
  expectFailure 'Missing image or checksum' flasher /dev/null
  test ! -e "$FAKE_NIX_LOG"

  dd if=/dev/zero of=fixture/sd-image/test.img bs=512 count=2
  (
    cd default-output
    exporter
    cmp "$FAKE_IMAGE_DIR/sd-image/test.img" .artifacts/home-pi.img
    (cd .artifacts; sha256sum --check home-pi.img.sha256)
    expectFailure 'Output already exists' exporter
    expectFailure 'Not a whole-disk' flasher /dev/null
    printf corrupted >> .artifacts/home-pi.img
    expectFailure 'Image checksum mismatch' flasher /dev/null
  )

  zstd fixture/sd-image/test.img -o compressed/sd-image/test.img.zst
  export FAKE_IMAGE_DIR="$PWD/compressed"
  (
    cd custom-output
    exporter --output 'nested/image with spaces.img'
    cmp ../fixture/sd-image/test.img 'nested/image with spaces.img'
    (cd nested; sha256sum --check 'image with spaces.img.sha256')
    expectFailure 'Not a whole-disk' flasher --input 'nested/image with spaces.img' /dev/null
    printf invalid > 'nested/image with spaces.img.sha256'
    expectFailure 'Invalid SHA-256' flasher --input 'nested/image with spaces.img' /dev/null
  )

  mkdir -p empty/sd-image
  export FAKE_IMAGE_DIR="$PWD/empty"
  expectFailure 'Expected exactly one' exporter --output empty.img
  test ! -e empty.img
  touch "$out"
''
