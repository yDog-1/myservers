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
NixOS のロールバックではリストもその世代の内容に戻ります。
SD イメージにも両リストが含まれるため、起動後の初回配置は不要です。

以前 layat で配置していたホストも、通常のデプロイで NixOS 管理のリンクへ切り替わります。
旧 layat profile は自動削除されません。移行後は旧 manifest による apply / reset を
実行しないでください。NixOS が管理する配置先への操作を避けるためです。

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
