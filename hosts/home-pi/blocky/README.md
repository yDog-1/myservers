# Blocky の設定とローカルリスト

Blocky は `-c /etc/blocky` で起動し、NixOS が配置する `00_base.yaml` を読み込みます。
この YAML は `/etc/blocky/allowlist.txt` と `/etc/blocky/denylist.txt` を
既存の `default` グループから参照します。外部 deny list も引き続き使用します。

両 `.txt` は layat が通常の **Nix store symlink** として配置します。
編集するのはチェックアウト内のファイルです。`/etc/blocky` 内のリンク先は読み取り専用で、
チェックアウトを編集しただけでは稼働中のリストは変わりません。
ドメインを1行ずつ記載してください。`#` で始まる行はコメントです。

home-pi 向けの配置定義はこのディレクトリの `layat.nix` にまとめています。
flake の公開名は `layat.<system>.home-pi-blocky-lists` です。
`<system>` は manifest をビルドする環境、`home-pi` は配置対象のホストを示します。

## deploy を実行する PC から配置

手元のチェックアウトで `nix develop` に入り、リストを編集して実行します。

```sh
# 初回は新設定の deploy 前にリストだけ配置
layat-home-pi
deploy-home-pi

# 稼働後のリスト更新は配置・検証・refresh をまとめて実行
layat-home-pi --refresh

# リポジトリ外から実行する場合
layat-home-pi --repo /absolute/path/to/myservers --refresh
```

`--repo` を省略すると現在の Git リポジトリルートを使用します。
コマンド実行時のチェックアウトをビルドするため、devShell に入った後の編集も反映されます。
commit / push は不要ですが、新規ファイルは Git に追加してから実行してください。
接続先は deploy と同じ `spec.home-pi` のユーザー・IP です。

処理は次の順序です。失敗した段階で停止し、後続処理は実行しません。

1. 手元の system 用の `layat.<system>.home-pi-blocky-lists` をビルド。
2. 同じ lock の `packages.aarch64-linux.home-pi-layat` を実現。
3. `nix copy --to ssh://<deploy-user>@<home-pi>` で manifest と CLI の closure を転送。
4. SSH 経由で manifest と両リストの配置元が読めることを確認し、転送済み CLI の絶対パスを使い、
   `sudo -n -H …/bin/layat apply home-pi-blocky-lists --manifest …` を実行。
5. `/etc/blocky` に配置した両リストが読めることを確認。
6. `--refresh` 指定時のみ、確認成功後に home-pi の `apply-blocky-config` を実行。

manifest は JSON と store source を参照する symlink なので、手元の system 用に
ビルドして home-pi で使用できます。実行する CLI は aarch64-linux 用です。
CLI は提供元のバイナリキャッシュから取得でき、キャッシュにない場合は
aarch64-linux をビルドできる builder が必要です。手元の一時 out-link は処理中の
GC root として保持し、成功・失敗のどちらでも終了時に削除します。

転送は参照先を含む closure 単位で行い、既にターゲットの store にある path は再送しません。
両リストは `writeText` で独立した store ファイルにし、manifest の依存関係に登録しています。
リポジトリ全体の snapshot を転送する必要はありません。layat の `toString src` に直接の
ファイルパスを渡すと string context が失われ、配置元が closure から漏れるため、
ここでは derivation を配置元にします。
home-pi にチェックアウトや事前インストール済み layat は不要です。
home-pi 側では Nix の評価・ビルドを行いませんが、profile 保存のために `nix-env` を使用します。

SSH は通常の鍵・agent・設定を使用し、非対話の BatchMode で接続します。
`sudo -n -H` と `XDG_STATE_HOME` の除去により root の標準 state directory を使います。
配置先 `/etc/blocky` と名前 `home-pi-blocky-lists` を揃えるため、以下の直接適用と
同じ root profile に履歴が保存されます。`--manifest` だけでは名前が `default` になるため、
名前は常に明示します。

配置と Blocky の反映は別操作です。配置後に検証・refresh が失敗した場合も新しい
symlink は残ります。原因を解消して再実行してください。layat の profile 保存に
失敗した場合もリンク更新が残ることがあるため、refresh には進まずエラーを返します。

## home-pi 上からの初回配置

home-pi 上の任意の場所へこのリポジトリを clone し、リポジトリルートで実行します。
初回 deploy **前**にリストを配置してください。

```sh
nix develop
sudo "$(command -v layat)" -f "$PWD" apply home-pi-blocky-lists
```

これにより `layat.aarch64-linux.home-pi-blocky-lists` がビルドされ、両ファイルが
`/etc/blocky` に配置されます。専用の Nix profile が store の参照を保持するため、
チェックアウトを移動・削除しても配置済みリストは利用できます。

## リストの更新

チェックアウト内の `allowlist.txt` / `denylist.txt` を編集した後、
同じリポジトリルートで実行します。

```sh
sudo "$(command -v layat)" -f "$PWD" apply home-pi-blocky-lists
apply-blocky-config
```

layat の配置は root 権限を必要とします。`nix develop` を抜けた後も、
home-pi に導入された `layat` を使えます。別の場所から配置する場合は
`sudo layat -f /absolute/path/to/myservers apply home-pi-blocky-lists` を使います。
初回は devShell の CLI と lib を、以後もできる限り同じ lock のバージョンに揃えてください。
新規ファイルは Git に追加してから flake に読み込ませてください。

`apply-blocky-config` は home-pi のシステム PATH に導入されるため、どこからでも
引数なしで実行できます。処理はサービスと同じ Blocky による次の2操作です。

1. `/etc/blocky` の設定を `validate` で検証する。
2. 成功した場合だけ `lists refresh` を実行する。

専用コマンドは Nix の評価・ビルドや layat の配置、サービス再起動を行いません。
リストの store ファイルと manifest の更新は `layat apply` が担当し、
NixOS 全体の再ビルドは不要です。

refresh は loopback の HTTP API (`127.0.0.1:4000`) を使い、
ローカルリストと外部 allow/deny list を再読み込みします。
`validate` は YAML の設定検証であり、外部リストの内容を完全に検証するものではありません。
YAML 自体の変更は refresh では反映されず、deploy によるサービス更新が必要です。

## deploy との関係

deploy / NixOS activation は layat を実行しません。NixOS は `00_base.yaml` と
CLI を管理し、両 `.txt` の配置は layat の独立した profile に任せます。
deploy や NixOS rollback によって配置済みリストは更新・巻き戻されません。
base の変更は Blocky の再起動トリガーになります。

## 旧 manifest 名からの移行

旧名 `blocky-lists` を適用済みの場合も、更新手順に従って
`home-pi-blocky-lists` を適用し、`apply-blocky-config` を実行してください。
同じ配置先の symlink を新しい profile で管理するようになります。
旧 profile は自動削除されません。新しい配置後に旧 profile の manifest で
`layat reset` を実行すると、同じ参照先の symlink を削除する可能性があるため、
旧名による apply / reset は以後使用しないでください。

## 検証

```sh
nix flake check
nix build .#layat.aarch64-linux.home-pi-blocky-lists --no-link
nix build .#layat-home-pi --no-link
```

Blocky のチェックは設定ディレクトリを検証します。実ホストのリスト取得・API 更新の
結果は `apply-blocky-config` と `journalctl --namespace=blocky -u blocky` で確認できます。
`layat-home-pi` のチェックはモックによる処理順序に加え、実際の manifest の closure に
両リストが含まれること、ファイルが読めること、チェックアウトの内容と一致することを確認します。
