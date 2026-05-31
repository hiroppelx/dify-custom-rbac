# dify-custom-rbac

🔐 **Dify のログアクセスを Owner / Admin ロールのみに制限する — コマンド1つで。**

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![ShellCheck](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/shellcheck.yml)
[![gitleaks](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/gitleaks.yml)
[![For Dify self-hosted](https://img.shields.io/badge/for-Dify%20self--hosted-1C64F2)](https://github.com/langgenius/dify)

> [English version / 英語版はこちら](README.md)

デフォルトのセルフホスト版 Dify では、**Editor 以上**の権限を持つユーザーがワークフローログ・会話ログを閲覧できます。**dify-custom-rbac** は認可チェックを追加し、**Owner** と **Admin** ロールのみがそれらのログにアクセスできるようにします。

> **免責:** これは独立したコミュニティ製ツールです。LangGenius / Dify プロジェクトとは **提携・承認・スポンサー関係にありません**。Dify のソースコードは再配布しておらず、スクリプトは **あなた自身の** Dify インストールにパッチを当てます。

---

## 目次

- [仕組み](#仕組み)
- [互換性](#互換性)
- [要件](#要件)
- [インストール](#インストール)
- [使い方](#使い方)
- [ロールバック](#ロールバック)
- [検証](#検証)
- [Dify のアップグレード](#dify-のアップグレード)
- [カスタム Docker イメージ](#カスタム-docker-イメージ)
- [制限事項と注意点](#制限事項と注意点)
- [セキュリティ](#セキュリティ)
- [トラブルシューティング](#トラブルシューティング)
- [コントリビュート](#コントリビュート)
- [ライセンス](#ライセンス)

---

## 仕組み

本ツールは Dify のログ系エンドポイントと UI に、小さく明確な認可チェックを追加します。

### バックエンド (API)

- **`api/controllers/console/app/workflow_app_log.py`** — ワークフローログへのアクセスを Owner/Admin に制限。
- **`api/controllers/console/app/conversation.py`** — 会話ログへのアクセスを Owner/Admin に制限（completion/chat の会話一覧・詳細の計4エンドポイント）。

チェックは統一されています:

```python
from models.account import TenantAccountRole
if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
    raise Forbidden("Only owner or admin can view logs")
```

Editor/Member ユーザーには **`403 Forbidden`** が返ります。

### フロントエンド (Web・任意)

- 非特権ロールに対して **Logs** ナビゲーション項目を非表示にし、ログ用ルートからリダイレクトします（`web/context/app-context.tsx`、`web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx`）。

フロントエンドの変更は多層防御 / UX 目的であり、実際の強制はバックエンドのチェックが担います。

### 適用方法は2通り

| 方法 | スクリプト | 内容 |
| --- | --- | --- |
| **ランタイムパッチ**（最速） | `apply-dify-rbac.sh` | 稼働中の API コンテナ内のファイルにパッチを当てて再起動。自動バックアップを作成。 |
| **カスタムイメージ**（再現性重視） | `build-custom-images.sh` + `docker-compose.override.yml` | **事前にパッチを当てた** Dify ソースツリーから `dify-*-custom-rbac` イメージをビルド（[カスタム Docker イメージ](#カスタム-docker-イメージ)参照）。稼働中コンテナへの直接パッチは行いません。 |

---

## 互換性

`dify-custom-rbac` は **Docker Compose でデプロイされたセルフホスト版 Dify** を対象とします。

特定の Dify ソースファイル・コードパターンにパッチを当てて動作を変えるため、**互換性はあなたの Dify バージョンに依存します**。以下のコードが存在し、一致していることが前提です:

| レイヤ | ファイル | 依存するパターン |
| --- | --- | --- |
| Backend | `api/controllers/console/app/workflow_app_log.py` | `def get(self, app_model: App)` |
| Backend | `api/controllers/console/app/conversation.py` | `if not current_user.is_editor:` |
| Backend | `models/account.py` | `TenantAccountRole.is_privileged_role()` |
| Frontend | `web/context/app-context.tsx` | `isCurrentWorkspaceEditor` / `isCurrentWorkspaceOwner` |
| Frontend | `web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx` | ログナビ項目 + ルートガード |

**特定の「対応バージョン」は意図的に固定していません。** 新しい / 古い Dify リリースではこのコードが移動・改名される可能性があります。本番適用の前に:

1. まず非破壊チェックを実行:
   ```bash
   ./apply-dify-rbac.sh --verify-only      # 現在の状態を確認
   ./dify-integrated-upgrade.sh --dry-run  # アップグレード内容をプレビュー
   ```
2. 対象パターンが変わっていると、パッチャは **`WARNING: Search pattern not found`** を表示します。これは *「パターンを更新するまで非互換」* の合図として扱ってください。
3. **Dify のイメージタグを固定**（`latest` を避ける）して動作を再現可能にしてください。

特定の Dify バージョンで検証できたら、issue や PR で共有いただけると、既知の動作バージョンとして記載できます。

---

## 要件

- **Docker Compose**（`docker compose`）で稼働中のセルフホスト版 **Dify**。
- 稼働中の Dify **API コンテナ**。
- **Bash**（Linux/macOS）。ランタイムパッチ方式では `docker` 経由のコンテナアクセス。
- カスタムイメージ方式では、イメージをビルドできる環境（`Dockerfile.web` 内で `npm run build` に Node ツールチェインを使用）。

---

## インストール

```bash
# メインスクリプトをダウンロードして実行権限を付与
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh -o apply-dify-rbac.sh
chmod +x apply-dify-rbac.sh
```

> **セキュリティ上の注意:** これはセキュリティツールです。`curl` をシェルに直接パイプするのではなく、**実行前にスクリプトの内容を確認してください**（`less apply-dify-rbac.sh`）。[SECURITY.md](SECURITY.md) を参照。

---

## 使い方

```bash
# 全自動（環境を信頼できる場合に推奨）
./apply-dify-rbac.sh --auto

# 段階実行（確認しながら）
./apply-dify-rbac.sh --interactive

# 現在の RBAC 状態のみ確認（非破壊）
./apply-dify-rbac.sh --verify-only

# 既定以外の Dify インストールを指定
./apply-dify-rbac.sh --dify-path /custom/path/dify --auto

# 変更を取り消す（直近の自動バックアップから復元）
./apply-dify-rbac.sh --rollback

# ヘルプ
./apply-dify-rbac.sh --help
```

スクリプトは Dify ディレクトリと Docker コンテナを自動検出し、タイムスタンプ付きバックアップを作成し、パッチを適用し、API コンテナを再起動し、結果を検証してレポートを表示します。

---

## ロールバック

適用のたびに `/tmp/dify-rbac-backup-*` 以下にタイムスタンプ付きバックアップが作成されるため、いつでも元に戻せます。

```bash
# 直近の適用をロールバック
./apply-dify-rbac.sh --rollback

# 利用可能なバックアップ一覧
ls -la /tmp/dify-rbac-backup-*
```

スタンドアロンのソースパッチャは `revert` サブコマンドを使います:

```bash
python3 backend-rbac-patch.py revert
node frontend-rbac-patch.js revert
```

---

## 検証

### ロール別アクセスマトリクス

| ロール | ログ API アクセス | 確認方法 | 期待結果 |
| --- | --- | --- | --- |
| **Owner** | ✅ 許可 | ログページを開く | 正常表示 |
| **Admin** | ✅ 許可 | ログページを開く | 正常表示 |
| **Editor** | ❌ 拒否 | ログページを開く | `403 Forbidden` |
| **Member** | ❌ 拒否 | ログページを開く | `403 Forbidden` |

### 手順

```bash
# 1. 自動チェック
./apply-dify-rbac.sh --verify-only

# 2. 手動チェック
#  - Owner/Admin でログイン → ログが見える
#  - Editor/Member でログイン → アクセス拒否（403）
```

---

## Dify のアップグレード

Dify のアップグレードはパッチ済みファイルを上書きし得るため、アップグレード後は RBAC を再適用してください。統合アップグレードスクリプトがこれを代行し、バックアップも保持します:

```bash
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/dify-integrated-upgrade.sh -o dify-integrated-upgrade.sh
chmod +x dify-integrated-upgrade.sh

./dify-integrated-upgrade.sh --dry-run      # プレビューのみ（変更なし）
./dify-integrated-upgrade.sh --interactive  # 段階実行
./dify-integrated-upgrade.sh --auto         # 自動
./dify-integrated-upgrade.sh --skip-rbac --auto  # Dify のみアップグレード
```

設定とボリュームをバックアップし、RBAC を一時的にロールバックし、Dify をアップグレードし、RBAC を再適用して結果を検証します。

<details>
<summary>手動アップグレード手順</summary>

```bash
# 1. 現在の RBAC 変更をロールバック
./apply-dify-rbac.sh --rollback

# 2. Dify をアップグレード
cd /path/to/dify
git pull origin main
docker compose pull
docker compose up -d

# 3. RBAC を再適用
cd /path/to/dify-custom-rbac
./apply-dify-rbac.sh --auto

# 4. 検証
./apply-dify-rbac.sh --verify-only
```
</details>

---

## カスタム Docker イメージ

再現性のあるデプロイのために、ランタイムでパッチを当てる代わりに、事前にパッチを当てたイメージをビルドできます。**`build-custom-images.sh` 自体はパッチを当てません** — 隣接する `../dify` ソースツリーからイメージをビルドするため、そのツリーが **あらかじめ RBAC 変更を含んでいる** 必要があります。

> **注意 — ビルド元のツリーにパッチを当ててください。** スタンドアロンのソースパッチャ（`backend-rbac-patch.py` / `frontend-rbac-patch.js`）は現状 `/root/dify` を既定の対象とし、パス引数を取りません。一方 `build-custom-images.sh` は `../dify` からビルドします。ビルド元のツリーが確実にパッチ済みになるようにしてください（例: Dify チェックアウトを `/root/dify` に置く、または `../dify` ツリーに同等の編集を手動で適用する）。その **後で** ビルドします。

```bash
# パッチ済みの Dify ソースツリー（隣接する ../dify）からイメージをビルド
./build-custom-images.sh
# 生成物: dify-api-custom-rbac:latest, dify-web-custom-rbac:latest

# Dify ディレクトリに override ファイルを置いてデプロイ
cp docker-compose.override.yml /path/to/dify/
docker compose up -d
```

> **デプロイ前に、ビルドしたイメージが実際に RBAC を強制するか必ず検証してください** — 未パッチのソースツリーからは、名前は `dify-*-custom-rbac` でも RBAC を強制しないイメージが生成されます:
>
> ```bash
> docker run --rm dify-api-custom-rbac:latest \
>   grep -q "is_privileged_role" \
>   /app/api/controllers/console/app/workflow_app_log.py \
>   && echo "RBAC あり" || echo "未パッチ — デプロイしないでください"
> ```
>
> 多くの場合、ランタイムパッチ方式（`apply-dify-rbac.sh --auto`。Dify を自動検出し `--dify-path` も使用可）の方が簡単で、この問題を回避できます。

詳細な手順（前提条件・環境設定・nginx ハードニング・監視・完了チェックリスト）は [DEPLOYMENT.md](DEPLOYMENT.md) を参照してください。

---

## 制限事項と注意点

- **バージョン結合。** Dify 内部のソース / UI パターンにパッチを当てるため、Dify のアップグレードで壊れることがあります。アップグレード後は必ず再検証してください。
- **Dify とは非提携。** 独立したコミュニティ製ツールであり、LangGenius / Dify プロジェクトによる製造・承認はありません。
- **`latest` ベースイメージ。** `Dockerfile.api` / `Dockerfile.web` は `FROM langgenius/dify-*:latest` でビルドします。再現性のためバージョンを固定してください。
- **ランタイムパッチは API コンテナを再起動**するため、短時間の中断が生じます。カスタムイメージ方式は稼働中コンテナへの直接パッチを避けられます。
- **フロントエンド変更には Web の再ビルドが必要**（`Dockerfile.web` が `npm run build` を実行）で、時間とリソースを要します。
- **対象はログ系エンドポイントのみ。** ワークフローログと会話ログを Owner/Admin に制限します。Dify の他機能に対する汎用 RBAC システムではありません。
- **セルフホスト専用。** ファイル / コンテナアクセスが必要で、Dify Cloud には適用できません。
- **テストスイート** はパッチ後の Dify コードを対象とし、実行には Dify 環境 / 依存関係が必要です。本リポジトリ単体の CI ゲートではなく、参照用です。

---

## セキュリティ

- 脆弱性報告の手順と脅威モデルは [SECURITY.md](SECURITY.md) を参照してください。
- 本リポジトリのスクリプトは `curl | bash` ではなく、**ダウンロードして内容を確認してから実行**することを推奨します。
- CI は push と pull request のたびに **ShellCheck** と **gitleaks**（シークレットスキャン・全履歴）を実行します。

---

## トラブルシューティング

<details>
<summary>適用後に API コンテナが起動しない</summary>

```bash
docker logs <api-container> --tail 50
docker restart <api-container>
sleep 30
./apply-dify-rbac.sh --verify-only
```
</details>

<details>
<summary>Editor がまだログにアクセスできる</summary>

```bash
# パッチの有無を確認し、必要なら再適用
./apply-dify-rbac.sh --verify-only
./apply-dify-rbac.sh --auto
```
</details>

<details>
<summary>Admin がログにアクセスできない</summary>

Dify 管理画面でユーザーのロールを確認し、ブラウザのキャッシュをクリアして、別のブラウザで試してください。
</details>

<details>
<summary><code>WARNING: Search pattern not found</code></summary>

お使いの Dify バージョンが対象コードを変更している可能性があります。[互換性](#互換性) を参照してください。部分的な変更を元に戻してパターンを更新するか、Dify バージョンを添えて issue を作成してください。
</details>

---

## コントリビュート

コントリビュート歓迎です！ [CONTRIBUTING.md](CONTRIBUTING.md) をお読みください。

これはコミュニティ運営のプロジェクトです: 変更が取り込まれる前に、**メンテナがすべての pull request をレビューし、すべての issue をトリアージ**します。マージとリリースはメンテナのみが行います。

提出前に:

```bash
shellcheck ./*.sh                       # lint（CI で強制）
gitleaks detect --source . --redact     # シークレットスキャン
```

---

## ライセンス

本プロジェクトのツールは [Apache License 2.0](LICENSE) の下で公開されています。帰属表示は [`NOTICE`](NOTICE) を参照してください。（Dify 自体は、追加条件付きの *改変版* Apache License 2.0 で配布されています。あなたのデプロイに適用される条件は、Dify 自身の [LICENSE](https://github.com/langgenius/dify/blob/main/LICENSE) を確認してください。）

---

## 言語

- [English](README.md)
- [日本語 / Japanese](README_ja.md)（このファイル）
