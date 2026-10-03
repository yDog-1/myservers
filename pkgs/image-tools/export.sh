usage() {
  cat <<'EOF'
Usage: export-home-pi-image [--output PATH]

Build the home-pi SD image and export a regular, uncompressed file.
Default output: .artifacts/home-pi.img (relative to the current directory).
Also writes PATH.sha256. An ARM builder or configured emulation is needed
when the image is not already built or cached.
EOF
}

output=.artifacts/home-pi.img
while (($#)); do
  case "$1" in
    --output)
      if (($# < 2)) || [[ -z "$2" || "$2" == --* ]]; then
        echo '--output requires a path' >&2
        exit 2
      fi
      output=$2
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -e "$output" || -L "$output" || -e "$output.sha256" || -L "$output.sha256" ]]; then
  echo "Output already exists: $output or $output.sha256" >&2
  exit 1
fi

storePath=$(nix build --no-link --print-out-paths \
  --extra-substituters "$HOME_PI_SUBSTITUTERS" \
  --extra-trusted-public-keys "$HOME_PI_PUBLIC_KEYS" \
  "$HOME_PI_IMAGE_DRV^out")
shopt -s nullglob
images=("$storePath"/sd-image/*.img.zst "$storePath"/sd-image/*.img)
if ((${#images[@]} != 1)); then
  echo "Expected exactly one SD image under $storePath/sd-image" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$output")"
temporary=$(mktemp -d "$(dirname -- "$output")/.home-pi-export.XXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
if [[ "${images[0]}" == *.zst ]]; then
  zstd --decompress --sparse -o "$temporary/image.img" -- "${images[0]}"
else
  cp --reflink=auto --sparse=always -- "${images[0]}" "$temporary/image.img"
fi

# Hash the final basename so the sidecar remains usable after moving the pair.
mkdir "$temporary/final"
mv -- "$temporary/image.img" "$temporary/final/$(basename -- "$output")"
(
  cd "$temporary/final"
  sha256sum -- "./$(basename -- "$output")"
) > "$temporary/image.sha256"
mv -T --update=none-fail -- "$temporary/final/$(basename -- "$output")" "$output"
mv -T --update=none-fail -- "$temporary/image.sha256" "$output.sha256"
echo "Exported: $output"
echo "Checksum: $output.sha256"
