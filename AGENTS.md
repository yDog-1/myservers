# Repository Guidelines

## Configuration boundaries
- `home-pi` is an `aarch64-linux` Raspberry Pi 3 system built through `nixos-raspberrypi.lib.nixosSystem`, not the root nixpkgs' NixOS builder.
- Keep `nixos-raspberrypi`'s nixpkgs input independent: its pin matches cached kernel builds. Root nixpkgs supplies developer tools, standalone checks, and the newer Blocky package required for `rebindingProtection`.
- Host usernames, deploy address, image options, and SSH keys are wired through `flake.nix`; host services live in `hosts/home-pi/`, shared OS modules in `modules/`.
- Cache URLs/keys originate in `flake.nix`'s `nixConfig` and are reused by `modules/base.nix` and the image exporter. Keep this shared source of truth.

## Verification and deployment
- `nix flake check` runs deploy-rs checks plus Linux-only `blocky-config` and `image-tools` checks. `--all-systems` includes foreign-system checks and needs corresponding builders/emulation.
- Focused Linux checks: `nix build .#checks.x86_64-linux.blocky-config` or `nix build .#checks.x86_64-linux.image-tools`; use `aarch64-linux` on ARM. Image-tool checks use fixtures and mocked Nix/sudo, without building an SD image or writing a disk.
- Evaluate host wiring without building: `nix eval .#nixosConfigurations.home-pi.config.system.build.toplevel.drvPath`.
- `nix develop` provides `deploy`, image tools, and the interactive alias `deploy-home-pi` = `deploy --skip-checks .#home-pi`. Run `nix flake check` separately when using this alias.
- Deployment uses `remoteBuild = false`: the initiating machine needs an ARM builder/emulation for uncached host builds. It connects as the dedicated deploy user and activates as root via passwordless sudo.
- `deploy` is a host Nix trusted user. Blocky settings and lists are deployed together through `environment.etc` and roll back with the NixOS generation.

## SD images
- The exporter builds `homePiImage`, an `extendModules` variant of the host with `hosts/home-pi/image.nix`; there is no standalone SD-image package output. Entering the dev shell/building the tools does not build the ARM image.
- `nix run .#export-home-pi-image -- --output PATH` (or `export-home-pi-image` in the dev shell) exports an uncompressed image plus `PATH.sha256`. Default: `.artifacts/home-pi.img`; existing image/sidecar files are never overwritten. Uncached images need an ARM builder/emulation.
- Linux only: `nix run .#flash-home-pi-image -- --input PATH /dev/disk/by-id/DEVICE`. Requires the exported checksum, a whole-disk target, host sudo, and interactive confirmation; verifies readback after writing.
- Image sources are copied into `/etc/nixos`. Image auto-upgrade is forced from `spec.home-pi.image.autoUpgradeEnable` (currently false), whereas the ordinary host enables weekly upgrades from GitHub with `--recreate-lock-file`.
- SD images include the Blocky settings and both local lists; no separate initial list placement is needed.
- Preserve the installed-server image overrides in `modules/sd-image.nix`: disabling the recovery/base profile avoids its ZFS build. Root `.artifacts/`, `result`, and `result-*` outputs are ignored.

## DNS and network gotchas
- Edit `hosts/home-pi/blocky/00_base.yaml`, not `services.blocky.settings`. NixOS installs it under `/etc/blocky`; Blocky runs with `-c /etc/blocky`. The upstream generated-YAML check is disabled; `pkgs/blocky-config-check.nix` validates the directory both in flake checks and host `system.checks`.
- Edit allow/deny lists in the checkout under `hosts/home-pi/blocky/`, not the read-only `/etc/blocky/*.txt` store links. `hosts/home-pi/blocky.nix` installs YAML and both lists with `environment.etc`; all three are Blocky restart triggers. Deploy local list changes like other NixOS changes.
- The host's `apply-blocky-config` validates `/etc/blocky`, then refreshes lists through `127.0.0.1:4000` only on success. Use it to refresh external lists with the current configuration; it does not place local files. See `hosts/home-pi/blocky/README.md` for deployment and migration notes.
- The host resolves through Blocky at `127.0.0.1`; keep bootstrap DNS independent of `/etc/resolv.conf`. Tailscale deliberately disables DNS acceptance, Tailscale SSH, and Taildrop, using Blocky and OpenSSH instead.
- Blocky logs use a journal namespace: inspect with `journalctl --namespace=blocky`, not only the default journal.

## Repository workflow
- Use Conventional Commits (e.g. `fix(deploy): ...`). Include verification commands and deployment-impacting changes in PR descriptions.
- The GitHub update workflow runs `nix flake update` once, shares the lock file with x86_64 and ARM64 validation jobs, and creates/squash-merges a PR only after both pass. ARM64 runs `nix flake check` and evaluates home-pi's toplevel; x86_64 evaluates flake outputs and builds the native `blocky-config`, `image-tools`, and `layat-home-pi` checks (the x86 deploy-rs checks reference ARM derivations). Merge is pinned to the PR head SHA; executions are serialized. PRs created with `GITHUB_TOKEN` do not trigger separate `pull_request` workflows, so keep these checks before PR creation and merge.
