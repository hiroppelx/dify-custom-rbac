# Dify カスタムRBAC実装

🔐 **DifyのログアクセスをOwner/Adminのみに制限するワンライナー自動化ツール**

デフォルトのDifyでは、Editor以上の権限を持つユーザーがワークフローログや会話ログを閲覧できますが、このツールによりOwner/Adminのみがアクセス可能になります。

## ✨ 特徴

- **🚀 ワンライナー実行**: 1つのコマンドで完全自動化
- **🔍 自動環境検出**: Difyインストールディレクトリ・Dockerコンテナを自動検出
- **💾 安全機能**: 自動バックアップ・完全ロールバック機能
- **✅ 動作検証**: RBAC実装の自動検証とレポート生成
- **🛠️ 柔軟対応**: 複数のパッチパターンで様々な環境に対応

## 📋 変更内容

### バックエンドAPI制限
- **workflow_app_log.py**: ワークフローログアクセスをOwner/Adminに制限
- **conversation.py**: 会話ログアクセスをOwner/Adminに制限（4つのAPIエンドポイント対応）
- **多層防御**: APIレベルでの完全なアクセス制御

### セキュリティ強化
- `TenantAccountRole.is_privileged_role()`を使用した統一ロール判定
- 403 Forbiddenエラーによる明確なアクセス拒否
- Editor/Memberユーザーへの適切なエラーメッセージ

## 📂 ファイル構成

```
dify-custom-rbac/
├── README.md                    # 英語版ドキュメント
├── README_ja.md                 # 日本語版ドキュメント（このファイル）
├── apply-dify-rbac.sh          # 🎯 メインのワンライナースクリプト
└── .gitignore                   # Git除外設定
```

## 🚀 超簡単導入手順

### 前提条件
- DifyがDocker Composeで起動済み
- Docker APIコンテナが稼働中
- bash環境（Linux/macOS）

### ワンコマンド実行

```bash
# 1. スクリプトをダウンロード＆実行権限付与
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh -o apply-dify-rbac.sh
chmod +x apply-dify-rbac.sh

# 2. 完全自動実行（推奨）
./apply-dify-rbac.sh --auto
```

**それだけです！** 🎉

### その他の実行オプション

```bash
# 段階的実行（確認しながら）
./apply-dify-rbac.sh --interactive

# 現在のRBAC状態確認
./apply-dify-rbac.sh --verify-only

# カスタムDifyパス指定
./apply-dify-rbac.sh --dify-path /custom/path/dify --auto

# ヘルプ表示
./apply-dify-rbac.sh --help

# 変更をロールバック
./apply-dify-rbac.sh --rollback
```

## 🎯 動作確認

### ロール別アクセス制御マトリックス

| ロール | ログAPI アクセス | 動作確認方法 | 期待結果 |
|--------|----------------|-------------|----------|
| **Owner** | ✅ **許可** | ログページアクセス | 正常表示 |
| **Admin** | ✅ **許可** | ログページアクセス | 正常表示 |
| **Editor** | ❌ **拒否** | ログページアクセス | 403 Forbidden / Internal Server Error |
| **Member** | ❌ **拒否** | ログページアクセス | 403 Forbidden / Internal Server Error |

### 検証手順

```bash
# 1. スクリプトでRBAC状態確認
./apply-dify-rbac.sh --verify-only

# 2. 手動テスト
# - Owner/AdminユーザーでログインしてログページにアクセスOK
# - Editor/Memberユーザーでログインしてログページにアクセス→エラー確認
```

## 🔄 メンテナンス

### Difyアップデート時の手順

```bash
# 1. 現在の設定をロールバック
./apply-dify-rbac.sh --rollback

# 2. Difyアップデート実行
cd /root/dify  # または、あなたのDifyインストールディレクトリ
git pull origin main
docker-compose pull
docker-compose up -d

# 3. RBACを再適用
cd /path/to/dify-custom-rbac
./apply-dify-rbac.sh --auto

# 4. 動作確認
./apply-dify-rbac.sh --verify-only
```

### バックアップの管理

```bash
# バックアップディレクトリ確認
ls -la /tmp/dify-rbac-backup-*

# 特定のバックアップからロールバック
BACKUP_DIR=/tmp/dify-rbac-backup-20250730-162641
./apply-dify-rbac.sh --rollback
```

## 🔧 トラブルシューティング

### よくある問題と解決法

#### ❌ **問題1**: "API container failed to start properly"
```bash
# 解決法
docker logs docker-api-1 --tail 50
docker restart docker-api-1
sleep 30
./apply-dify-rbac.sh --verify-only
```

#### ❌ **問題2**: Editorでもログアクセスできてしまう
```bash
# 解決法: パッチ状態確認
./apply-dify-rbac.sh --verify-only

# 再適用が必要な場合
./apply-dify-rbac.sh --auto
```

#### ❌ **問題3**: Adminでログアクセスできない
```bash
# 解決法: ロール確認とキャッシュクリア
# 1. Dify管理画面でユーザーロール確認
# 2. ブラウザのキャッシュクリア
# 3. 別ブラウザで確認
```

### ログ確認コマンド

```bash
# RBAC関連ロググ
docker logs docker-api-1 | grep -i "rbac\|forbidden\|privilege"

# エラーログ全般
docker logs docker-api-1 --tail 100

# コンテナ状態確認
docker ps -f name=docker-api-1
```

## 📊 監視とセキュリティ

### 監視推奨事項

- **403エラー数**: Editor/Memberからの不正アクセス試行
- **ログAPI呼び出し頻度**: 異常なアクセスパターン検出
- **ユーザーロール変更**: 権限昇格の監視

### セキュリティベストプラクティス

1. **定期検証**: 月1回の動作確認
2. **バックアップ保持**: 直近3回分のバックアップ保持
3. **ログ監視**: APIアクセスログの定期確認
4. **権限監査**: ユーザーロールの定期見直し

## ⚡ 高速デプロイガイド

### 新環境での初回セットアップ

```bash
# ワンライナーセットアップ
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh | bash -s -- --auto
```

### CI/CD統合例

```yaml
# GitHub Actions例
- name: Apply Dify RBAC
  run: |
    curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh -o apply-dify-rbac.sh
    chmod +x apply-dify-rbac.sh
    ./apply-dify-rbac.sh --auto
    ./apply-dify-rbac.sh --verify-only
```

## 💡 実装技術詳細

### パッチ対象ファイル

1. **`api/controllers/console/app/workflow_app_log.py`**
   - ワークフローログAPI
   - `TenantAccountRole.is_privileged_role()`チェック追加

2. **`api/controllers/console/app/conversation.py`**
   - 会話ログAPI（4つのエンドポイント）
   - CompletionConversationApi
   - CompletionConversationDetailApi
   - ChatConversationApi
   - ChatConversationDetailApi

### セキュリティ実装

```python
# 追加されるRBACチェック
from models.account import TenantAccountRole
if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
    raise Forbidden("Only owner or admin can view logs")
```

## 🌐 多言語対応

- [English](README.md) - 英語版README
- [日本語](README_ja.md) - 日本語版README（このファイル）

## 📞 サポート

- **🐛 バグレポート**: [GitHubでIssue作成](https://github.com/hiroppelx/dify-custom-rbac/issues)
- **💡 機能要望**: [GitHubでDiscussion作成](https://github.com/hiroppelx/dify-custom-rbac/discussions)
- **🔐 セキュリティ問題**: セキュリティチーム直接連絡
- **📖 英語版ドキュメント**: [README.md](README.md)

## 🙏 貢献

プルリクエストとフィードバックを歓迎します！

### 貢献者向けクイックスタート

```bash
# フォーク後
git clone https://github.com/your-username/dify-custom-rbac.git
cd dify-custom-rbac

# テスト環境で確認
./apply-dify-rbac.sh --interactive

# プルリクエスト作成
git checkout -b feature/your-improvement
git commit -m "feat: your improvement"
git push origin feature/your-improvement
```

### 開発ガイドライン

1. **コード品質**: シェルスクリプトのベストプラクティスに従う
2. **テスト**: 複数環境での動作確認
3. **ドキュメント**: 変更内容の明確な説明
4. **互換性**: 既存インストールへの影響を最小化

## ⚖️ ライセンス

このプロジェクトはApache License 2.0の下で公開されています。Difyプロジェクトと同じライセンスを使用しています。

## 📚 関連リンク

- **Dify公式**: https://github.com/langgenius/dify
- **Difyドキュメント**: https://docs.dify.ai/
- **Docker**: https://www.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/

---

## 🎉 まとめ

**たった1つのコマンドでDifyのログアクセスを完全に制御！**

```bash
./apply-dify-rbac.sh --auto
```

- ✅ **安全**: 自動バックアップ・ロールバック対応
- ✅ **簡単**: ワンコマンド実行
- ✅ **確実**: 動作検証・レポート生成
- ✅ **柔軟**: 多様な環境に対応

**🔐 Owner/Adminのみがログアクセス可能になりました！**

---

*このツールは、企業環境でのDify運用時のセキュリティ要件を満たすために開発されました。安全で効率的なDify管理をサポートします。*