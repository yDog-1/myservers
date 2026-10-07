# myservers

自宅サーバーの NixOS 構成を管理する Nix flake です。現在は Raspberry Pi 3 の `home-pi` を管理しています。

## 現行構成

| 項目 | 設定 |
| --- | --- |
| ホスト | `home-pi`（Raspberry Pi 3 / `aarch64-linux`） |
| 有線 LAN | `192.168.0.100/24`、ゲートウェイ `192.168.0.1` |
| ユーザー | `ydog`（通常利用）、`deploy`（デプロイ用） |
| SSH | OpenSSH、公開鍵認証のみ |
| DNS | Blocky、TCP/UDP 53 番ポートを開放 |
| VPN | Tailscale |
| ロケール / タイムゾーン | `ja_JP.UTF-8` / `Asia/Tokyo` |
| スワップ | 1 GiB の `/swapfile` とメモリの 50% の zram |

Wi-Fi と Bluetooth は無効です。ユーザー名、デプロイ先 IP、SSH 公開鍵、イメージの自動更新設定は `flake.nix` で管理しています。`ydog` と `deploy` はパスワードなしで sudo を利用できます。

ホストは `nixos-raspberrypi.lib.nixosSystem` で構築します。`nixos-raspberrypi` の nixpkgs は、キャッシュ済みカーネルとの整合性を保つため、ルートの nixpkgs とは独立した入力です。ルートの nixpkgs は開発ツール、単独の検証、および `rebindingProtection` に対応する Blocky パッケージに使用します。

## ディレクトリ構成

```text
flake.nix                     ホスト、デプロイ、開発シェル、アプリ、チェックの定義
flake.lock                    依存関係の固定
hosts/home-pi/
  default.nix                 ネットワーク、ユーザー、SSH、自動更新など
  blocky.nix                  Blocky サービス、DNS、ログ管理
  blocky.yaml                 Blocky の実際の設定ファイル
  tailscale.nix               Tailscale の設定
  image.nix                   SD イメージ用のホスト設定の上書き
modules/
  base.nix                    ロケール、基本ツール、Nix キャッシュなど
  rpi3.nix                    Raspberry Pi 3 とファームウェア領域の設定
  swap.nix                    スワップと zram
  sd-image.nix                インストール済みサーバー用 SD イメージの設定
pkgs/
  blocky-config-check.nix     Blocky 設定の検証
  image-tools/                SD イメージのエクスポート、書き込み、検証
.github/workflows/            flake.lock 更新 PR の作成
```

## 開発環境と検証

Nix の `nix-command` と `flakes` を有効にした環境で、リポジトリのルートから実行します。

```sh
nix develop
nix flake check
```

開発シェルは `x86_64-linux`、`aarch64-linux`、`aarch64-darwin` に対応し、`deploy`、SSH、Git、イメージツールを提供します。SD カードへの書き込みツールは Linux のみで利用できます。シェルへの入場やツールのビルドだけでは ARM の SD イメージはビルドされません。

`nix flake check` は deploy-rs のチェックに加え、Linux では `blocky-config` と `image-tools` を実行します。個別に確認する場合は次を使います（ARM Linux では `x86_64-linux` を `aarch64-linux` に置き換えてください）。

```sh
nix build .#checks.x86_64-linux.blocky-config
nix build .#checks.x86_64-linux.image-tools
```

イメージツールのチェックはフィクスチャと Nix / sudo のモックを使用するため、実際の SD イメージのビルドやディスクへの書き込みは行いません。`nix flake check --all-systems` は別アーキテクチャのチェックも含むため、対応するビルダーやエミュレーションが必要です。

ホスト構成をビルドせずに評価するには、次を実行します。

```sh
nix eval .#nixosConfigurations.home-pi.config.system.build.toplevel.drvPath
```

## デプロイ

`flake.nix` の SSH 公開鍵に対応する秘密鍵と、`192.168.0.100` への接続が必要です。開発シェル内で次を実行します。

```sh
nix flake check
deploy-home-pi
```

`deploy-home-pi` は対話シェル用のエイリアスで、`deploy --skip-checks .#home-pi` を実行します。チェックを省略するため、`nix flake check` を別途実行してください。deploy-rs のチェックを含めて直接実行する場合は `deploy .#home-pi` を使用します。

デプロイは `deploy` ユーザーで SSH 接続し、パスワードなしの sudo を通じて root としてシステムを有効化します。`remoteBuild = false` のため、ビルドはデプロイ元で行います。キャッシュにない ARM の成果物をビルドするには、デプロイ元で ARM ビルダーまたはエミュレーションを利用できる必要があります。

## SD イメージの作成と書き込み

SD イメージは通常の `home-pi` 構成に `hosts/home-pi/image.nix` を追加した派生構成です。単独の SD イメージ用 package 出力はなく、エクスポートツールを通じてビルドします。

### エクスポート

```sh
nix run .#export-home-pi-image -- --output .artifacts/home-pi.img
```

開発シェル内では次のようにも実行できます。

```sh
export-home-pi-image --output .artifacts/home-pi.img
```

`--output` の既定値は `.artifacts/home-pi.img` です。非圧縮のイメージと `.artifacts/home-pi.img.sha256` を出力し、既存のイメージやチェックサムは上書きしません。キャッシュにないイメージのビルドには ARM ビルダーまたはエミュレーションが必要です。

バイナリキャッシュの URL と公開鍵は `flake.nix` の `nixConfig` に定義され、ホスト設定とエクスポートツールで共有しています。

### SD カードへの書き込み（Linux のみ）

`/dev/disk/by-id/DEVICE` を対象の SD カード全体を指すデバイスパスに置き換えて実行します。パーティションではなくディスク全体を指定してください。

```sh
nix run .#flash-home-pi-image -- --input .artifacts/home-pi.img /dev/disk/by-id/DEVICE
```

開発シェル内では `flash-home-pi-image --input .artifacts/home-pi.img /dev/disk/by-id/DEVICE` も利用できます。イメージに対応する `.sha256` ファイルと、実行環境の sudo が必要です。

ツールはチェックサムを確認し、書き込み先を表示して対話的な確認を求めます。書き込み先の既存データは消去されます。書き込み後はイメージ分のデータを読み戻して検証します。

イメージには構成のソースを `/etc/nixos` に配置します。イメージの自動更新は `flake.nix` の `spec.home-pi.image.autoUpgradeEnable` に従い、現在は無効です。通常のホスト構成をデプロイすると、後述の週次自動更新が有効になります。

## DNS と Tailscale

Blocky の設定を変更する場合は `hosts/home-pi/blocky.yaml` を編集します。このファイルが `/etc/blocky/config.yaml` に配置され、flake のチェックとホストの `system.checks` で検証されます。

- 上流 DNS は Cloudflare と Google の DNS over TLS を使用します。
- 広告や悪性ドメインのブロックリストを使用し、24 時間ごとに更新します。
- DNS rebinding protection を有効にしています。
- ホスト自身も `127.0.0.1` の Blocky で名前解決します。循環参照を避けるため、bootstrap DNS は `/etc/resolv.conf` に依存せず、IP アドレス指定の DNS over TLS を使用します。
- Tailscale の DNS 受け入れ、Tailscale SSH、Taildrop は無効です。名前解決には Blocky、SSH 接続やファイル転送には OpenSSH を利用します。

初回の Tailscale 認証は、ホストへ SSH 接続して行います。

```sh
ssh ydog@192.168.0.100
sudo tailscale up --accept-dns=false --ssh=false
```

Blocky のログは専用の journal namespace に保存します。確認には次を使用します。

```sh
sudo journalctl --namespace=blocky -u blocky.service
```

ログはおおむね 1 日の保持期間を設定し、毎時のクリーンアップでローテーションと古いログの削除を行います。

## 自動更新とメンテナンス

通常のホスト構成は、週次で `github:yDog-1/myservers#home-pi` から自動更新します。更新時には `--recreate-lock-file` を指定し、最大 45 分のランダム遅延を設け、自動再起動は行いません。Nix ストアの GC も週次で実行し、7 日より古い世代を削除します。

GitHub Actions は毎週月曜日 03:00 UTC または手動実行で `nix flake update` を実行し、`flake.lock` 更新 PR を作成して自動マージを有効にします。このワークフローでは構成のチェックを実行しないため、依存関係の変更はローカルで検証してください。

生成物の `.artifacts/`、`result`、`result-*` は Git の管理対象外です。
