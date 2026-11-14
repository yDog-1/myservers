# myservers

Raspberry Pi 3 の自宅サーバー `home-pi` を管理する NixOS 構成です。

## 準備

Nix の `nix-command` と `flakes` を有効にし、リポジトリのルートで開発環境に入ります。

```sh
nix develop
```

デプロイとリスト更新には、`deploy@192.168.0.100` へ接続できる SSH 鍵が必要です。キャッシュにない ARM 用の成果物をビルドする場合は、ARM ビルダーまたはエミュレーションを用意してください。

## デプロイ

構成や Blocky のリストを変更したら、検証してデプロイします。
初回も同じ手順で、設定とリストがまとめて配置されます。

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
nix flake check
deploy-home-pi
```

- 編集した内容は commit / push なしで反映できます。
- `/etc/blocky` 内のリストは直接編集せず、リポジトリ内のファイルを編集してください。
- 設定とリストは NixOS の `environment.etc` で配置し、変更時には Blocky が自動で再起動します。
- リストも NixOS の世代に含まれ、移行後の世代間ではロールバック時にその世代の内容に戻ります。移行前の世代へ戻す場合は、[復旧手順](hosts/home-pi/blocky/README.md#layat-からの移行と復旧)に従ってください。

サーバー上からの操作や移行手順は、[Blocky の運用手順](hosts/home-pi/blocky/README.md)を参照してください。

## Lanchpad の設定

`home-pi` は Discord bot の Lanchpad を systemd サービスとして実行します。設定ファイルがない場合、サービスは起動をスキップします。SD イメージにも設定ファイルは含まれません。

1. Discord のアプリケーションと bot を作成し、使用するサーバーに追加します。Discord 側でコマンドを使えるユーザーやロールを制限してください。Lanchpad 自体には利用者の認可機能がありません。
2. `home-pi` 上で `sudo install -d -m 0700 /var/lib/secrets` を実行します。
3. `sudoedit /var/lib/secrets/lanchpad.env` で次の内容を作成し、実際の値に置き換えます。ブロードキャスト先は対象 PC の LAN に合わせてください。

   ```text
   DISCORD_BOT_TOKEN=実際のbotトークン
   DISCORD_APP_ID=アプリケーションID
   DISCORD_GUILD_ID=サーバーID
   WOL_TARGETS=desktop=00:11:22:33:44:55@192.168.0.255:9
   ```

4. `sudo chown root:root /var/lib/secrets/lanchpad.env` と `sudo chmod 600 /var/lib/secrets/lanchpad.env` を実行します。
5. 設定をデプロイした後、`sudo systemctl start lanchpad` を実行します。ファイル作成後に自動起動を待つ必要はありません。
6. `sudo journalctl -u lanchpad -n 50 --no-pager` でログを確認し、Discord で `/echo` と `/wol` を試します。

設定ファイルは systemd の EnvironmentFile 形式です。シェルスクリプトとして実行せず、Git や Nix store に入れないでください。設定変更後は `sudo systemctl restart lanchpad` を実行します。ファイルの内容は NixOS 世代に含まれないため、ロールバックされません。起動時に指定した Discord サーバーのアプリケーションコマンド一覧が上書きされます。`/wol` の成功応答はパケット送信を示し、PC の起動完了は保証しません。

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
- SD イメージには設定とリストが含まれ、起動後の初回配置は不要です。

## 自動更新の注意

通常の構成は週次で自動更新され、自動再起動は行いません。SD イメージでは自動更新を無効にしています。

GitHub Actions による依存関係更新では構成チェックを実行しないため、変更は手元で検証してください。古い世代は週次の GC で削除されるため、長期保存が必要な世代は別途保持してください。
