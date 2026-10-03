usage() {
  cat <<'EOF'
Usage: flash-home-pi-image [--input PATH] DEVICE

Write an exported image to a whole SD card, then verify a direct readback.
Default input: .artifacts/home-pi.img (relative to the current directory).
PATH.sha256 is required. DEVICE is mandatory; prefer /dev/disk/by-id/...
The target is displayed and must be confirmed before unmounting or writing.
Uses the host's sudo. An unmount failure stops the operation.
EOF
}

input=.artifacts/home-pi.img
deviceArgument=
while (($#)); do
  case "$1" in
    --input)
      if (($# < 2)) || [[ -z "$2" || "$2" == --* ]]; then
        echo '--input requires a path' >&2
        exit 2
      fi
      input=$2
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [[ -n "$deviceArgument" ]]; then
        echo 'Exactly one device is required' >&2
        exit 2
      fi
      deviceArgument=$1
      shift
      ;;
  esac
done
if [[ -z "$deviceArgument" ]]; then
  usage >&2
  exit 2
fi
if [[ ! -f "$input" || ! -f "$input.sha256" ]]; then
  echo "Missing image or checksum: $input, $input.sha256" >&2
  echo 'Run export-home-pi-image first.' >&2
  exit 1
fi

expected=
if ! read -r expected _ < "$input.sha256" && [[ -z "$expected" ]]; then
  echo 'Invalid SHA-256 sidecar' >&2
  exit 1
fi
expected=${expected#\\}
if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'Invalid SHA-256 sidecar' >&2
  exit 1
fi
actual=$(sha256sum < "$input")
if [[ "${actual%% *}" != "$expected" ]]; then
  echo 'Image checksum mismatch' >&2
  exit 1
fi
imageSize=$(stat -c %s -- "$input")
if ((imageSize == 0 || imageSize % 512 != 0)); then
  echo 'Image must be nonempty and aligned to 512-byte sectors' >&2
  exit 1
fi
device=$(realpath -e -- "$deviceArgument")
if [[ ! -b "$device" ]] || [[ "$(lsblk -dnro TYPE -- "$device")" != disk ]]; then
  echo "Not a whole-disk block device: $deviceArgument" >&2
  exit 1
fi
deviceSize=$(lsblk -bdnro SIZE -- "$device")
if ((deviceSize < imageSize)); then
  echo 'Device is smaller than the image' >&2
  exit 1
fi
layout=$(lsblk --json --paths --output NAME,TYPE,MOUNTPOINTS -- "$device")
if jq -e '[.. | objects | .mountpoints? // [] | .[] |
  select(. == "/" or . == "/boot" or . == "/boot/efi" or
    . == "/nix" or . == "/nix/store" or . == "[SWAP]")] | length > 0' \
  <<< "$layout" > /dev/null; then
  echo 'Refusing to overwrite a system disk or active swap device' >&2
  exit 1
fi

lsblk --output NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS,MODEL -- "$device"
echo "Image: $input ($imageSize bytes)"
echo "Target: $deviceArgument -> $device"
echo "All existing data on $device will be overwritten."
read -r -p "Type $device to continue: " confirmation
if [[ "$confirmation" != "$device" ]]; then
  echo 'Cancelled.' >&2
  exit 1
fi
sudo -v
mapfile -t mountedDevices < <(jq -r '[.. | objects |
  select(has("name")) | select(any(.mountpoints[]?; . != null and . != "")) |
  .name] | reverse | .[]' <<< "$layout")
for mountedDevice in "${mountedDevices[@]}"; do
  sudo "$(type -P umount)" --all-targets -- "$mountedDevice"
done

# Recheck after confirmation/unmounting, including the original by-id reference.
if [[ "$(realpath -e -- "$deviceArgument")" != "$device" ]] ||
  [[ "$(lsblk -bdnro SIZE -- "$device")" != "$deviceSize" ]]; then
  echo 'Target device changed; refusing to write' >&2
  exit 1
fi
if ! lsblk --json --output MOUNTPOINTS -- "$device" |
  jq -e '[.. | objects | .mountpoints? // [] | .[] |
    select(. != null and . != "")] | length == 0' > /dev/null; then
  echo 'Device still has mounted filesystems; refusing to write' >&2
  exit 1
fi

sudo "$(type -P dd)" if="$input" of="$device" bs=4M conv=fsync status=progress
readback=$(sudo "$(type -P dd)" if="$device" bs=4M iflag=direct,count_bytes \
  count="$imageSize" status=progress | sha256sum)
if [[ "${readback%% *}" != "$expected" ]]; then
  echo 'SD card readback checksum mismatch' >&2
  exit 1
fi
echo "Verified: $device ($expected)"
echo 'The card can now be safely removed.'
