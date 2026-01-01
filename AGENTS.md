# Repository Guidelines

## Project Structure & Module Organization
This repository is a Nix flake that defines NixOS configurations. Key paths:
- `flake.nix`: entry point, inputs, host specs, deploy-rs config, dev shells.
- `hosts/home-pi/`: host-specific NixOS module (`default.nix`).
- `modules/`: shared modules such as `base.nix`, `rpi3.nix`, `swap.nix`.
- `flake.lock`: pinned input versions.
There are no dedicated test or asset directories; evaluation and deploy checks are driven by the flake outputs.

## Build, Test, and Development Commands
- `nix develop`: enters the dev shell with deploy tooling and helper alias.
- `deploy-home-pi`: shorthand for `deploy --skip-checks .#home-pi` (remote build).
- `nix run github:serokell/deploy-rs -- .#home-pi`: run deploy-rs directly.
- `nix flake check`: evaluate NixOS config and deploy checks (may skip non-local systems).
- `nix flake check --all-systems`: validate checks across supported systems.

## Coding Style & Naming Conventions
- Nix files use 2-space indentation and trailing commas in lists/attrs.
- Prefer small, composable modules under `modules/` and host wiring in `hosts/`.
- Host-specific settings live under `spec` in `flake.nix`.
- Attribute names use lowerCamelCase (e.g., `deployUserName`, `ipAddress`).

## Testing Guidelines
- Primary validation is `nix flake check` which runs `deployChecks`.
- There is no separate unit test framework in this repo.
- If you add new checks, keep them platform-aware to avoid cross-arch failures.

## Commit & Pull Request Guidelines
- Commits follow Conventional Commits: `feat:`, `fix:`, `refactor:`; scopes are optional (e.g., `feat(deploy): ...`).
- Keep commit bodies descriptive and multi-line for notable changes.
- PRs should describe intent, list commands run (`nix flake check`), and note any deploy-impacting changes.

## Security & Configuration Notes
- SSH access is key-based; keep `authorizedKeys` current.
- Deploy uses a dedicated user with NOPASSWD sudo for non-interactive activation.
- IPs are defined in `spec` and used for both network config and deploy target.
