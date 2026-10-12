# myservers

Raspberry Pi 3 の自宅サーバー `home-pi` を管理する NixOS 構成です。

## 準備

Nix の `nix-command` と `flakes` を有効にし、リポジトリのルートで開発環境に入ります。

```sh
nix develop
```

デプロイとリスト更新には、`deploy@192.168.0.100` へ接続できる SSH 鍵が必要です。キャッシュにない ARM 用の成果物をビルドする場合は、ARM ビルダーまたはエミュレーションを用意してください。

## デプロイ

初回は、Blocky が使用するリストを先に配置します。

```sh
layat-home-pi
```

構成を変更したら、検証してデプロイします。

```sh
nix flake check
deploy-home-pi
```

`deploy-home-pi` はチェックを省略するため、事前に `nix flake check` を実行してください。

## Blocky のリスト更新

次のファイルにドメインを1行ずつ記載します。`#` で始まる行はコメントです。

- 許可：`hosts/home-pi/blocky/allowlist.txt`
- 拒否：`hosts/home-pi/blocky/denylist.txt`

編集後、次を実行します。

```sh
layat-home-pi --refresh
```

- 編集した内容は commit / push なしで反映できます。
- `/etc/blocky` 内のリストは直接編集せず、リポジトリ内のファイルを編集してください。
- リスト更新に NixOS 全体のデプロイは不要です。基本設定の `00_base.yaml` を変更した場合はデプロイしてください。
- デプロイや NixOS rollback は、配置済みリストを更新・巻き戻しません。
- 配置後の検証・再読み込みに失敗しても、新しいリストは配置されたままです。原因を解消して再実行してください。

サーバー上からの操作や移行手順は、[Blocky の運用手順](hosts/home-pi/blocky/README.md)を参照してください。

## 接続とログ確認

```sh
ssh ydog@192.168.0.100

# サーバー上で初回の Tailscale 認証
sudo tailscale up --accept-dns=false --ssh=false

# サーバー上で Blocky のログを確認
sudo journalctl --namespace=blocky -u blocky.service
```

Tailscale 接続後は、その IP アドレスでも通常の SSH を利用できます。Blocky のログ保持期間はおおむね1日です。

## SD イメージの作成と書き込み

開発環境内で実行します。書き込みは Linux のみ対応しています。

```sh
export-home-pi-image --output .artifacts/home-pi.img
flash-home-pi-image --input .artifacts/home-pi.img /dev/disk/by-id/DEVICE
```

- `DEVICE` は対象の SD カード全体を指すパスに置き換えてください。書き込み先の既存データは消去されます。
- 出力先に既存のイメージやチェックサムがある場合、エクスポートは停止します。
- 書き込みには、イメージと同時に出力される `.sha256` ファイルが必要です。
- 新規 SD カードでは、起動後にリストの初回配置が必要です。[サーバー上からの配置手順](hosts/home-pi/blocky/README.md#home-pi-上からの初回配置)を参照してください。

## 自動更新の注意

通常の構成は週次で自動更新され、自動再起動は行いません。SD イメージでは自動更新を無効にしています。

GitHub Actions による依存関係更新では構成チェックを実行しないため、変更は手元で検証してください。古い世代は週次の GC で削除されるため、長期保存が必要な世代は別途保持してください。
