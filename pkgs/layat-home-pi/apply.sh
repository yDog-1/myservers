usage() {
  printf '%s\n' \
    'Usage: layat-home-pi [--repo PATH] [--refresh]' \
    'Build and transfer Blocky lists and the pinned home-pi CLI, then apply over SSH.' \
    'Defaults to the current Git repository. --refresh also validates and refreshes Blocky.'
}

repo_input=.
refresh=false
while (( $# > 0 )); do
  case "$1" in
    --repo)
      if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then
        printf '%s\n' '--repo requires a path' >&2
        exit 1
      fi
      repo_input=$2
      shift 2
      ;;
    --refresh)
      refresh=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

repo=$(git -C "$repo_input" rev-parse --show-toplevel)
for file in flake.nix flake.lock hosts/home-pi/blocky/layat.nix; do
  if [[ ! -f "$repo/$file" ]]; then
    printf 'Missing repository file: %s\n' "$repo/$file" >&2
    exit 1
  fi
done

work=$(mktemp -d "${TMPDIR:-/tmp}/layat-home-pi.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT

printf 'Building home-pi lists from %s\n' "$repo"
nix build --no-update-lock-file --out-link "$work/manifest" \
  "$repo#layat.$HOME_PI_LOCAL_SYSTEM.home-pi-blocky-lists"
nix build --no-update-lock-file --out-link "$work/layat" \
  "$repo#packages.aarch64-linux.home-pi-layat"
manifest=$(readlink -f "$work/manifest")
target_layat=$(readlink -f "$work/layat")

# Only Nix store paths are interpolated into the remote shell command.
for path in "$manifest" "$target_layat"; do
  if [[ ! "$path" =~ ^/nix/store/[a-z0-9]{32}-[a-zA-Z0-9+._?=-]+$ ]]; then
    printf 'Unexpected build output: %s\n' "$path" >&2
    exit 1
  fi
done

printf 'Transferring lists and CLI to %s\n' "$HOME_PI_SSH_TARGET"
export NIX_SSHOPTS="${NIX_SSHOPTS:+$NIX_SSHOPTS }-o BatchMode=yes"
nix copy --to "ssh://$HOME_PI_SSH_TARGET" "$manifest" "$target_layat"

printf 'Applying home-pi-blocky-lists on %s\n' "$HOME_PI_SSH_TARGET"
ssh -T -o BatchMode=yes "$HOME_PI_SSH_TARGET" \
  "/run/current-system/sw/bin/bash -s -- '$target_layat' '$manifest' '$refresh'" <<'REMOTE'
set -euo pipefail
target_layat=$1
manifest=$2
refresh=$3

# The prebuilt apply path does not verify store-backed sources itself.
if [[ ! -r "$manifest/manifest.json" ]]; then
  printf 'Unreadable manifest: %s\n' "$manifest" >&2
  exit 1
fi
source_count=0
for source in "$manifest"/*; do
  if [[ -L "$source" ]]; then
    if [[ ! -r "$source" ]]; then
      printf 'Unreadable manifest source: %s\n' "$source" >&2
      exit 1
    fi
    (( source_count += 1 ))
  fi
done
if (( source_count != 2 )); then
  printf 'Expected two Blocky list sources, found %s\n' "$source_count" >&2
  exit 1
fi

sudo -n -H /run/current-system/sw/bin/env -u XDG_STATE_HOME \
  PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin \
  "$target_layat/bin/layat" apply home-pi-blocky-lists --manifest "$manifest"

for list in /etc/blocky/allowlist.txt /etc/blocky/denylist.txt; do
  if [[ ! -r "$list" ]]; then
    printf 'Unreadable deployed list: %s\n' "$list" >&2
    exit 1
  fi
done

if [[ "$refresh" == true ]]; then
  /run/current-system/sw/bin/apply-blocky-config
fi
REMOTE

printf 'home-pi lists applied successfully (refresh=%s)\n' "$refresh"
