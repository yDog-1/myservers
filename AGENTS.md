# Repository Guidelines

## Configuration boundaries
- `home-pi` is an `aarch64-linux` Raspberry Pi 3 system built through `nixos-raspberrypi.lib.nixosSystem`, not the root nixpkgs' NixOS builder.
- Keep `nixos-raspberrypi`'s nixpkgs input independent: its pin matches cached kernel builds. Root nixpkgs supplies developer tools, standalone checks, and the newer Blocky package required for `rebindingProtection`.
- Keep `layat`'s nixpkgs independent too, matching the provider's tested CLI and binary cache. Its cache URL/key are also declared in `nixConfig`.
- Host usernames, deploy address, image options, and SSH keys are wired through `flake.nix`; host services live in `hosts/home-pi/`, shared OS modules in `modules/`.
- Cache URLs/keys originate in `flake.nix`'s `nixConfig` and are reused by `modules/base.nix` and the image exporter. Keep this shared source of truth.

## Verification and deployment
- `nix flake check` runs deploy-rs checks plus Linux-only `blocky-config`, `image-tools`, and `layat-home-pi` checks. `--all-systems` includes foreign-system checks and needs corresponding builders/emulation.
- Focused Linux checks: `nix build .#checks.x86_64-linux.blocky-config` or `nix build .#checks.x86_64-linux.image-tools`; use `aarch64-linux` on ARM. Image-tool checks use fixtures and mocked Nix/sudo, without building an SD image or writing a disk.
- `nix build .#checks.x86_64-linux.layat-home-pi` checks mocked transfer/apply/refresh and failure ordering, plus the real manifest closure and list contents. It does not contact home-pi.
- Evaluate host wiring without building: `nix eval .#nixosConfigurations.home-pi.config.system.build.toplevel.drvPath`.
- `nix develop` provides `deploy`, `layat`, `layat-home-pi`, image tools, and the interactive alias `deploy-home-pi` = `deploy --skip-checks .#home-pi`. Run `nix flake check` separately when using this alias.
- Deployment uses `remoteBuild = false`: the initiating machine needs an ARM builder/emulation for uncached host builds. It connects as the dedicated deploy user and activates as root via passwordless sudo.
- `deploy` is a host Nix trusted user. Before the first deploy of the directory-based Blocky config, run `layat-home-pi` to place both referenced lists. Deploy/NixOS rollback does not apply or roll back layat profiles.

## SD images
- The exporter builds `homePiImage`, an `extendModules` variant of the host with `hosts/home-pi/image.nix`; there is no standalone SD-image package output. Entering the dev shell/building the tools does not build the ARM image.
- `nix run .#export-home-pi-image -- --output PATH` (or `export-home-pi-image` in the dev shell) exports an uncompressed image plus `PATH.sha256`. Default: `.artifacts/home-pi.img`; existing image/sidecar files are never overwritten. Uncached images need an ARM builder/emulation.
- Linux only: `nix run .#flash-home-pi-image -- --input PATH /dev/disk/by-id/DEVICE`. Requires the exported checksum, a whole-disk target, host sudo, and interactive confirmation; verifies readback after writing.
- Image sources are copied into `/etc/nixos`. Image auto-upgrade is forced from `spec.home-pi.image.autoUpgradeEnable` (currently false), whereas the ordinary host enables weekly upgrades from GitHub with `--recreate-lock-file`.
- Image creation/activation does not populate the layat list profile; a fresh SD installation needs initial list placement after boot. See `hosts/home-pi/blocky/README.md` for the on-host procedure.
- Preserve the installed-server image overrides in `modules/sd-image.nix`: disabling the recovery/base profile avoids its ZFS build. Root `.artifacts/`, `result`, and `result-*` outputs are ignored.

## DNS and network gotchas
- Edit `hosts/home-pi/blocky/00_base.yaml`, not `services.blocky.settings`. NixOS installs it under `/etc/blocky`; Blocky runs with `-c /etc/blocky`. The upstream generated-YAML check is disabled; `pkgs/blocky-config-check.nix` validates the directory both in flake checks and host `system.checks`.
- Edit allow/deny lists in the checkout under `hosts/home-pi/blocky/`, not the read-only `/etc/blocky/*.txt` store links. `layat.nix` exposes `layat.<system>.home-pi-blocky-lists`; preserve `writeText` sources so both lists remain closure dependencies and profile GC roots.
- Use `layat-home-pi [--repo PATH] --refresh` (or `nix run .#layat-home-pi -- --refresh`) from the PC to build the current checkout's manifest and pinned ARM CLI, copy closures, then apply via SSH with root's profile. This path needs no target checkout or target evaluation/build; an uncached CLI needs an ARM builder on the initiating machine.
- The host's `apply-blocky-config` validates `/etc/blocky`, then refreshes lists through `127.0.0.1:4000` only on success. List refresh needs no restart/rebuild; YAML changes need deployment. Failed validation/refresh does not undo already applied links. See `hosts/home-pi/blocky/README.md` for direct apply and old-profile migration.
- The host resolves through Blocky at `127.0.0.1`; keep bootstrap DNS independent of `/etc/resolv.conf`. Tailscale deliberately disables DNS acceptance, Tailscale SSH, and Taildrop, using Blocky and OpenSSH instead.
- Blocky logs use a journal namespace: inspect with `journalctl --namespace=blocky`, not only the default journal.

## Repository workflow
- Use Conventional Commits (e.g. `fix(deploy): ...`). Include verification commands and deployment-impacting changes in PR descriptions.
- The GitHub update workflow runs `nix flake update`, validates the updated lock with `nix flake check` on `x86_64-linux`, and evaluates home-pi's toplevel before creating/updating and squash-merging the PR. Merge is pinned to the PR head SHA; executions are serialized. This does not build the full ARM host system. PRs created with `GITHUB_TOKEN` do not trigger separate `pull_request` workflows, so keep these checks before PR creation and merge.
