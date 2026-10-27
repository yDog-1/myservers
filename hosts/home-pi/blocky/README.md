# Blocky の設定とローカルリスト

Blocky は `-c /etc/blocky` で起動します。`hosts/home-pi/blocky.nix` の
`environment.etc` が次のファイルを Nix store への読み取り専用 symlink として配置します。

- `00_base.yaml`：基本設定。既存の `default` グループから両ローカルリストを参照します。
- `allowlist.txt`：許可するドメイン。
- `denylist.txt`：拒否するドメイン。外部 deny list も引き続き使用します。

編集するのはチェックアウト内のファイルです。`/etc/blocky` 内は直接編集しないでください。
リストにはドメインを1行ずつ記載します。`#` で始まる行はコメントです。

## PC から更新

リポジトリルートで設定またはリストを編集し、次を実行します。

```sh
nix develop
nix flake check
deploy-home-pi
```

現在のチェックアウトの内容が反映されるため、commit / push は不要です。
新規ファイルを追加した場合は Git に追加してから実行してください。
初回も同じ手順で、設定とリストがまとめて配置されます。
設定またはリストが変わると Blocky が自動で再起動し、新しい内容を読み込みます。

## home-pi 上から更新

home-pi 上のチェックアウトを編集した場合は、リポジトリルートで実行します。

```sh
sudo nixos-rebuild switch --flake .#home-pi
```

## 世代管理と SD イメージ

設定とリストは同じ NixOS の世代に含まれ、システムの profile が store の参照を保持します。
移行後の世代間の NixOS ロールバックではリストもその世代の内容に戻ります。
SD イメージにも両リストが含まれるため、起動後の初回配置は不要です。

## layat からの移行と復旧

以前 layat で配置していたホストも、通常のデプロイで NixOS 管理のリンクへ切り替わります。
初回移行前に home-pi 上で次を実行し、両リストの store パスを記録してください。
旧 layat profile は復旧用に保持してください。移行時に自動削除はされません。

```sh
readlink -f /etc/blocky/allowlist.txt
readlink -f /etc/blocky/denylist.txt
```

**移行前の NixOS 世代へ戻す場合、リストは自動復元されません。**
旧世代の activation は NixOS 管理のリストリンクを削除しますが、以前の layat の
リンクは復元しません。初回デプロイ失敗時の deploy-rs による自動ロールバックでも
同様です。旧世代に戻った後、home-pi 上で記録した実際の store パスに置き換えて復旧します。

```sh
sudo ln -sfn /nix/store/RECORDED-ALLOWLIST-PATH /etc/blocky/allowlist.txt
sudo ln -sfn /nix/store/RECORDED-DENYLIST-PATH /etc/blocky/denylist.txt
sudo systemctl restart blocky.service
```

移行前に記録していなかった場合は、保持している旧 layat profile の manifest から
配置元の store パスを確認してください。
NixOS 管理の世代で稼働中は、旧 manifest による apply / reset を実行しないでください。

## 外部リストの手動再読み込みとログ

ローカルファイルを変更せず、現在の設定で外部リストを再取得したい場合は、
home-pi 上で次を実行できます。

```sh
apply-blocky-config
sudo journalctl --namespace=blocky -u blocky.service
```

`apply-blocky-config` はサービスと同じ Blocky で `/etc/blocky` を `validate` し、
成功した場合だけ `lists refresh` を実行します。refresh は loopback の HTTP API
(`127.0.0.1:4000`) を使います。設定やローカルファイルの配置は行いません。
`validate` は YAML の設定検証であり、外部リストの内容を完全に検証するものではありません。

## 検証

```sh
nix flake check
nix eval .#nixosConfigurations.home-pi.config.system.build.toplevel.drvPath
```

Blocky のチェックは設定ディレクトリを検証します。実ホストのリスト取得・API 更新の
結果は `apply-blocky-config` と journal で確認できます。
