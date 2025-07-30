# Dify Custom RBAC 詳細導入手順

## 前提条件

### 必要なソフトウェア

- Docker & Docker Compose
- Git
- Python 3.8+
- Node.js 16+
- 10GB以上の空きディスク容量

### 推奨環境

- Ubuntu 20.04 LTS 以上
- 4GB RAM以上
- 2 CPU以上

## Step-by-Step 導入手順

### Step 1: 環境準備

```bash
# システムパッケージ更新
sudo apt update && sudo apt upgrade -y

# Docker インストール（未インストールの場合）
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker Compose インストール
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 一度ログアウト・ログインしてDockerグループを反映
```

### Step 2: Difyリポジトリのセットアップ

```bash
# 作業ディレクトリ作成
mkdir -p ~/dify-deployment
cd ~/dify-deployment

# Dify公式リポジトリをクローン
git clone https://github.com/langgenius/dify.git
cd dify

# 最新の安定版をチェックアウト（推奨）
git checkout $(git describe --tags --abbrev=0)

# 基本設定
cp .env.example .env
```

### Step 3: RBACカスタマイズのセットアップ

```bash
# RBACカスタマイズディレクトリを作成
cd ~/dify-deployment
mkdir dify-custom-rbac
cd dify-custom-rbac

# カスタマイズファイルをここに配置
# （提供されたファイルをすべてコピー）
```

### Step 4: 環境設定

```bash
cd ~/dify-deployment/dify

# .envファイルを編集
nano .env
```

**重要な設定項目:**

```env
# セキュリティ設定
SECRET_KEY=your-very-secure-secret-key-here
ENCRYPTION_KEY=your-32-char-encryption-key-here

# データベース設定
DB_USERNAME=postgres
DB_PASSWORD=your-secure-password
DB_HOST=db
DB_PORT=5432
DB_DATABASE=dify

# Redis設定
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password

# RBAC関連（カスタム環境変数）
DIFY_RBAC_ENABLED=true
DIFY_RBAC_VERSION=1.0.0
DIFY_RBAC_LOG_ATTEMPTS=true
```

### Step 5: パッチ適用

```bash
cd ~/dify-deployment/dify-custom-rbac

# バックエンドパッチ適用
python3 backend-rbac-patch.py

# 適用結果確認
echo "=== Backend Patch Results ==="
echo "Modified files:"
ls -la ../dify/api/controllers/console/app/*.backup

# フロントエンドパッチ適用
node frontend-rbac-patch.js

# 適用結果確認
echo "=== Frontend Patch Results ==="
echo "Modified files:"
ls -la ../dify/web/context/*.backup
ls -la ../dify/web/app/\(commonLayout\)/app/\(appDetailLayout\)/\[appId\]/*.backup
```

### Step 6: カスタムDockerイメージビルド

```bash
# ビルドスクリプト実行
./build-custom-images.sh

# ビルド結果確認
docker images | grep dify-.*-custom-rbac

# 期待される出力:
# dify-api-custom-rbac  latest  xxx  xxx  xxxMB
# dify-web-custom-rbac  latest  xxx  xxx  xxxMB
```

### Step 7: Docker Compose設定

```bash
cd ~/dify-deployment/dify

# カスタムdocker-compose設定をコピー
cp ../dify-custom-rbac/docker-compose.override.yml .

# （オプション）カスタムNginx設定
mkdir -p docker/nginx/conf.d
cp ../dify-custom-rbac/nginx.custom.conf docker/nginx/conf.d/default.conf

# docker-compose.ymlを確認
docker-compose config
```

### Step 8: 初回起動

```bash
# データベースとRedisを先に起動（推奨）
docker-compose up -d db redis

# データベース初期化を待つ
sleep 30

# 全サービス起動
docker-compose up -d

# 起動状況確認
docker-compose ps

# ログ確認
docker-compose logs -f api web
```

### Step 9: 動作確認

#### 基本動作確認

```bash
# APIヘルスチェック
curl http://localhost/health

# Webアクセス確認
curl -I http://localhost/

# 期待される応答: HTTP/1.1 200 OK
```

#### RBAC機能確認

1. **管理者アカウント作成**
   - ブラウザで `http://localhost` にアクセス
   - 初期セットアップを完了
   - Ownerアカウントを作成

2. **テストユーザー作成**
   - Editorロールのユーザーを作成
   - Memberロールのユーザーを作成

3. **ログアクセステスト**
   - Ownerでログアクセス: ✅ 成功
   - Adminでログアクセス: ✅ 成功
   - Editorでログアクセス: ❌ 403エラーまたはリダイレクト
   - Memberでログアクセス: ❌ 403エラーまたはリダイレクト

### Step 10: 監視・ログ設定

```bash
# ログディレクトリ作成
sudo mkdir -p /var/log/dify
sudo chown -R $USER:$USER /var/log/dify

# ログローテーション設定
sudo tee /etc/logrotate.d/dify << EOF
/var/log/nginx/dify_log_access.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 nginx nginx
    postrotate
        docker-compose exec nginx nginx -s reload
    endscript
}
EOF
```

## トラブルシューティング

### 一般的な問題と解決策

#### 1. パッチ適用エラー

**症状**: `WARNING: Search pattern not found`

**解決策**:
```bash
# Difyのバージョンを確認
cd ~/dify-deployment/dify
git describe --tags

# パッチスクリプトを戻してやり直し
cd ../dify-custom-rbac
python3 backend-rbac-patch.py revert
node frontend-rbac-patch.js revert

# 手動でファイルをチェックして修正
```

#### 2. Dockerビルドエラー

**症状**: `build context size exceeds limit`

**解決策**:
```bash
# .dockerignoreファイルを作成
cd ~/dify-deployment/dify
tee .dockerignore << EOF
.git
node_modules
*.log
.env
*.backup
EOF

# 再ビルド
cd ../dify-custom-rbac
./build-custom-images.sh
```

#### 3. データベース接続エラー

**症状**: `could not connect to server`

**解決策**:
```bash
# データベースコンテナの状態確認
docker-compose ps db

# データベースログ確認
docker-compose logs db

# データベース再起動
docker-compose restart db

# データベース接続テスト
docker-compose exec db psql -U postgres -d dify -c "SELECT version();"
```

#### 4. メモリ不足エラー

**症状**: `OutOfMemoryError` または `Killed`

**解決策**:
```bash
# システムメモリ確認
free -h

# Dockerリソース制限を設定
# docker-compose.ymlに以下を追加:
services:
  api:
    mem_limit: 2g
  web:
    mem_limit: 1g
```

### デバッグ手順

#### 1. ログ詳細確認

```bash
# 全サービスのログ
docker-compose logs --tail=100

# 特定サービスのログ
docker-compose logs -f api
docker-compose logs -f web
docker-compose logs -f nginx

# リアルタイムログ監視
tail -f /var/log/nginx/dify_log_access.log
```

#### 2. コンテナ内部調査

```bash
# APIコンテナに入る
docker-compose exec api bash

# 設定ファイル確認
cat /app/api/controllers/console/app/workflow_app_log.py | grep -A5 -B5 "RBAC"

# プロセス確認
ps aux | grep python
```

#### 3. ネットワーク診断

```bash
# ポート確認
ss -tlnp | grep -E "(80|5001|3000)"

# コンテナ間通信テスト
docker-compose exec web curl http://api:5001/health
```

## バックアップとリストア

### バックアップ作成

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/dify-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# データベースバックアップ
docker-compose exec -T db pg_dump -U postgres dify | gzip > $BACKUP_DIR/database.sql.gz

# 設定ファイルバックアップ
cp .env $BACKUP_DIR/
cp docker-compose.override.yml $BACKUP_DIR/

# アプリケーションデータバックアップ
docker-compose exec -T api tar czf - /app/api/storage | cat > $BACKUP_DIR/app-storage.tar.gz

echo "Backup completed: $BACKUP_DIR"
```

### リストア手順

```bash
#!/bin/bash
# restore.sh

BACKUP_DIR=$1

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

# データベースリストア
zcat $BACKUP_DIR/database.sql.gz | docker-compose exec -T db psql -U postgres dify

# 設定ファイルリストア
cp $BACKUP_DIR/.env .
cp $BACKUP_DIR/docker-compose.override.yml .

# アプリケーションデータリストア
cat $BACKUP_DIR/app-storage.tar.gz | docker-compose exec -T api tar xzf - -C /

echo "Restore completed from: $BACKUP_DIR"
```

## 性能最適化

### 推奨設定

```yaml
# docker-compose.override.yml に追加
version: '3'
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
    environment:
      - WORKER_PROCESSES=4
      - MAX_WORKERS=8
      
  web:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 1G
          
  nginx:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### キャッシュ設定

```nginx
# nginx.custom.conf に追加
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header Vary Accept-Encoding;
    gzip_static on;
}
```

## セキュリティ強化

### SSL/TLS設定

```bash
# Let's EncryptでSSL証明書取得
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# Nginx設定更新
sudo nano docker/nginx/conf.d/default.conf
# SSL設定のコメントアウトを解除して証明書パスを更新
```

### ファイアウォール設定

```bash
# UFWでファイアウォール設定
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 5001/tcp  # APIポートは外部からアクセス不可
sudo ufw deny 3000/tcp  # Webポートは外部からアクセス不可
```

### セキュリティヘッダー

```nginx
# nginx.custom.conf に追加
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; media-src 'self'; object-src 'none'; child-src 'self'; frame-ancestors 'none'; form-action 'self'; base-uri 'self';" always;
```

## 完了チェックリスト

- [ ] Difyリポジトリのクローン完了
- [ ] パッチ適用完了（バックエンド・フロントエンド）
- [ ] カスタムDockerイメージビルド完了
- [ ] docker-compose.override.yml配置完了
- [ ] 環境変数設定完了
- [ ] 初回起動成功
- [ ] 管理者アカウント作成完了
- [ ] RBAC機能テスト完了
- [ ] ログ設定完了
- [ ] バックアップスクリプト設定完了
- [ ] SSL証明書設定完了（本番環境の場合）
- [ ] ファイアウォール設定完了（本番環境の場合）
- [ ] 監視設定完了（本番環境の場合）

## 次のステップ

1. **ユーザートレーニング**: チーム向けの使用方法説明
2. **監視設定**: Prometheus/Grafanaでメトリクス監視
3. **定期バックアップ**: cronでの自動バックアップ設定
4. **更新計画**: 定期的なDifyアップデート計画
5. **インシデント対応**: 問題発生時の対応手順書作成