#!/bin/bash
# Dify統合アップグレードスクリプト（RBAC対応）
# Author: Dify RBAC Project
# Version: 1.0.0

set -e

# 出力用カラー
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # 色リセット

# グローバル変数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFY_ROOT=""
RBAC_SCRIPT=""
BACKUP_ROOT=""
BACKUP_DIR=""
SKIP_RBAC="false"
DRY_RUN="false"
FORCE="false"
MODE="interactive"

# ログ関数
log_info() {
    echo -e "${BLUE}[情報]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[エラー]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[ステップ]${NC} $1"
}

# ヘルプ表示関数
show_help() {
    cat << EOF
Dify統合アップグレードスクリプト（RBAC対応）

使い方:
    $0 [オプション]

オプション:
    --auto              完全自動実行
    --interactive       ステップごとに確認（デフォルト）
    --dry-run           実行せずに内容のみ表示
    --skip-rbac         RBAC操作をスキップ（Difyのみアップグレード）
    --force             チェック失敗時も強制実行
    --dify-path パス    Difyインストールディレクトリ指定
    --rbac-script パス  RBACスクリプトのパス指定
    --backup-root パス  バックアップ保存先ディレクトリ指定
    --help              このヘルプを表示

例:
    $0 --auto                                    # 完全自動アップグレード
    $0 --interactive                             # ステップごとに確認
    $0 --dry-run                                 # 変更内容のみプレビュー
    $0 --skip-rbac --auto                        # Difyのみアップグレード
    $0 --dify-path /custom/dify --auto           # Difyパスを指定

説明:
    このスクリプトはRBAC設定を保持しつつDifyの完全なアップグレードを行います：
    1. アップグレード前の検証とバックアップ
    2. RBACロールバック（有効時）
    3. Difyアップグレード（Git pull + Docker再起動）
    4. RBAC再適用（有効時）
    5. アップグレード後の検証
    6. 詳細なレポート出力

RBAC連携:
    - apply-dify-rbac.shを自動検出・利用
    - Difyアップグレード時もRBAC設定を保持
    - アップグレード失敗時のロールバック機能
    - アップグレード後のRBAC動作検証
EOF
}

# コマンドライン引数の解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                MODE="auto"
                shift
                ;;
            --interactive)
                MODE="interactive"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-rbac)
                SKIP_RBAC="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --dify-path)
                DIFY_ROOT="$2"
                shift 2
                ;;
            --rbac-script)
                RBAC_SCRIPT="$2"
                shift 2
                ;;
            --backup-root)
                BACKUP_ROOT="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知のオプション: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Difyインストールディレクトリの検出
detect_dify_directory() {
    log_info "Difyインストールディレクトリを検出しています..."
    
    if [[ -n "$DIFY_ROOT" && -d "$DIFY_ROOT" ]]; then
        log_success "指定されたDifyディレクトリを使用します: $DIFY_ROOT"
        return 0
    fi
    
    # 一般的なDifyインストールパス
    local candidates=(
        "$HOME/dify"
        "/root/dify"
        "$(pwd)/dify"
        "/opt/dify"
        "$HOME/dify/docker"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            # ドッカーサブディレクトリかどうかをチェック
            if [[ "$(basename "$candidate")" == "docker" ]] && [[ -f "$candidate/docker-compose.yaml" ]]; then
                DIFY_ROOT="$(dirname "$candidate")"
                log_success "Difyインストールを見つけました: $DIFY_ROOT (dockerディレクトリから検出)"
                return 0
            # メインのdifyディレクトリかどうかをチェック
            elif [[ -d "$candidate/docker" ]] && [[ -f "$candidate/docker/docker-compose.yaml" ]]; then
                DIFY_ROOT="$candidate"
                log_success "Difyインストールを見つけました: $DIFY_ROOT"
                return 0
            fi
        fi
    done
    
    log_error "Difyインストールディレクトリが見つかりませんでした"
    log_error "Difyパスを--dify-path /path/to/difyで指定してください"
    exit 1
}

# RBACスクリプトの検出
detect_rbac_script() {
    if [[ "$SKIP_RBAC" == "true" ]]; then
        log_info "RBAC操作はスキップされます（--skip-rbac指定）"
        return 0
    fi
    
    log_info "RBACスクリプトを検出しています..."
    
    if [[ -n "$RBAC_SCRIPT" && -f "$RBAC_SCRIPT" ]]; then
        log_success "指定されたRBACスクリプトを使用します: $RBAC_SCRIPT"
        return 0
    fi
    
    # RBACスクリプトを検索
    local candidates=(
        "$SCRIPT_DIR/apply-dify-rbac.sh"
        "$(pwd)/apply-dify-rbac.sh"
        "$HOME/dify-custom-rbac/apply-dify-rbac.sh"
        "/root/dify-custom-rbac/apply-dify-rbac.sh"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" && -x "$candidate" ]]; then
            RBAC_SCRIPT="$candidate"
            log_success "RBACスクリプトを見つけました: $RBAC_SCRIPT"
            return 0
        fi
    done
    
    log_warning "RBACスクリプトが見つかりませんでした。RBAC操作はスキップされます。"
    log_warning "RBACサポートを有効にするには、apply-dify-rbac.shが利用可能で実行可能であることを確認してください。"
    SKIP_RBAC="true"
}

# バックアップディレクトリのセットアップ
setup_backup() {
    if [[ -n "$BACKUP_ROOT" ]]; then
        local backup_root="$BACKUP_ROOT"
    else
        local backup_root="$HOME/dify_backups"
    fi
    
    BACKUP_DIR="$backup_root/$(date '+%Y-%m-%d-%H%M%S_%Z')"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_success "バックアップディレクトリを作成しました: $BACKUP_DIR"
    else
        log_info "[DRY RUN] バックアップディレクトリを作成します: $BACKUP_DIR"
    fi
}

# アップグレード前の検証
pre_upgrade_validation() {
    log_step "アップグレード前の検証を実行しています..."
    
    # 正しいディレクトリ構造かどうかをチェック
    if [[ ! -d "$DIFY_ROOT/docker" ]]; then
        log_error "無効なDifyディレクトリ構造です: $DIFY_ROOT/dockerが見つかりません"
        exit 1
    fi
    
    if [[ ! -f "$DIFY_ROOT/docker/docker-compose.yaml" ]]; then
        log_error "docker-compose.yamlが見つかりません: $DIFY_ROOT/docker"
        exit 1
    fi
    
    # Dockerが実行中かどうかをチェック
    if ! docker info >/dev/null 2>&1; then
        log_error "Dockerが実行されていませんまたはアクセスできません"
        exit 1
    fi
    
    # Difyコンテナが実行中かどうかをチェック
    if ! docker ps --format "{{.Names}}" | grep -E "(api|web)" >/dev/null; then
        if [[ "$FORCE" != "true" ]]; then
            log_error "Difyコンテナが実行されていません。--forceを指定して続行します。"
            exit 1
        else
            log_warning "Difyコンテナが実行されていませんが、--forceが指定されています。続行します..."
        fi
    fi
    
    # Gitの状態をチェック
    cd "$DIFY_ROOT"
    if [[ -d ".git" ]]; then
        local git_status=$(git status --porcelain 2>/dev/null || echo "error")
        if [[ "$git_status" != "" && "$git_status" != "error" ]]; then
            log_warning "作業ディレクトリに未コミットの変更があります:"
            git status --short
            if [[ "$FORCE" != "true" && "$MODE" != "auto" ]]; then
                read -p "続行しますか？ (y/N): " -r
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "アップグレードがキャンセルされました"
                    exit 0
                fi
            fi
        fi
    fi
    
    log_success "アップグレード前の検証が完了しました"
}

# 現在の設定をバックアップ
backup_configuration() {
    log_step "現在の設定をバックアップしています..."
    
    cd "$DIFY_ROOT/docker"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # docker-compose.yamlのバックアップ
        cp docker-compose.yaml "$BACKUP_DIR/docker-compose.yaml.$(date '+%Y-%m-%d-%H%M%S_%Z').bak"
        log_success "docker-compose.yamlをバックアップしました"
        
        # volumesディレクトリのバックアップ
        if [[ -d "volumes" ]]; then
            log_info "volumesディレクトリをバックアップしています... (時間がかかる可能性あり)"
            tar -czf "$BACKUP_DIR/volumes-$(date '+%Y-%m-%d-%H%M%S_%Z').tgz" volumes
            log_success "volumesディレクトリをバックアップしました"
        fi
        
        # .envファイルが存在する場合はバックアップ
        if [[ -f ".env" ]]; then
            cp .env "$BACKUP_DIR/.env.$(date '+%Y-%m-%d-%H%M%S_%Z').bak"
            log_success "バックアップしました: .envファイル"
        fi
        
        # バックアップマニフェストの作成
        cat > "$BACKUP_DIR/backup_manifest.txt" << EOF
Dify統合アップグレードバックアップ
作成日: $(date)
Difyルート: $DIFY_ROOT
RBACスクリプト: ${RBAC_SCRIPT:-"未使用"}
RBACスキップ: $SKIP_RBAC

バックアップされたファイル:
- docker-compose.yaml
$([ -d "volumes" ] && echo "- volumes/ディレクトリ")
$([ -f ".env" ] && echo "- .envファイル")

アップグレード前のDockerコンテナ:
$(docker ps --filter "name=dify" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}")
EOF
        log_success "バックアップマニフェストを作成しました"
    else
        log_info "[DRY RUN] docker-compose.yamlをバックアップします"
        log_info "[DRY RUN] volumesディレクトリをバックアップします"
        [[ -f ".env" ]] && log_info "[DRY RUN] .envファイルをバックアップします"
    fi
}

# RBACロールバック
rbac_rollback() {
    if [[ "$SKIP_RBAC" == "true" ]]; then
        log_info "RBACロールバックはスキップされます（--skip-rbac指定）"
        return 0
    fi
    
    log_step "RBAC設定をロールバックしています..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if "$RBAC_SCRIPT" --rollback; then
            log_success "RBACロールバックが完了しました"
        else
            log_warning "RBACロールバックに失敗しましたまたは不要でした"
        fi
    else
        log_info "[DRY RUN] コマンドを実行します: $RBAC_SCRIPT --rollback"
    fi
}

# Difyアップグレード
dify_upgrade() {
    log_step "Difyアップグレードを実行しています..."
    
    cd "$DIFY_ROOT"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # 最新のコードをmainブランチから取得
        log_info "GitHubから最新コードを取得しています..."
        git checkout main
        git pull origin main
        log_success "コードが更新されました"
        
        # サービスを停止
        log_info "Difyサービスを停止しています..."
        cd docker
        docker compose down
        log_success "サービスが停止されました"
        
        # サービスを起動
        log_info "Difyサービスを起動しています..."
        docker compose up -d
        log_success "サービスが起動されました"
        
        # サービスが準備完了するのを待つ
        log_info "サービスが初期化を待っています..."
        sleep 30
        
        # コンテナが実行中かどうかをチェック
        local retries=12
        while [[ $retries -gt 0 ]]; do
            if docker ps --filter "name=dify" --format "{{.Names}}" | grep -E "(api|web)" >/dev/null; then
                log_success "Difyサービスが実行中です"
                break
            fi
            sleep 10
            ((retries--))
            if [[ $retries -gt 0 ]]; then
                log_info "サービスがまだ準備中です... ($retries回目残り)"
            fi
        done
        
        if [[ $retries -eq 0 ]]; then
            log_error "Difyサービスが適切に起動できませんでした"
            log_error "ログを確認するには: docker compose logs"
            exit 1
        fi
    else
        log_info "[DRY RUN] コマンドを実行します: git checkout main"
        log_info "[DRY RUN] コマンドを実行します: git pull origin main"
        log_info "[DRY RUN] コマンドを実行します: docker compose down"
        log_info "[DRY RUN] コマンドを実行します: docker compose up -d"
    fi
}

# RBAC再適用
rbac_reapply() {
    if [[ "$SKIP_RBAC" == "true" ]]; then
        log_info "RBAC再適用はスキップされます（--skip-rbac指定）"
        return 0
    fi
    
    log_step "RBAC設定を再適用しています..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if "$RBAC_SCRIPT" --auto; then
            log_success "RBAC再適用が完了しました"
        else
            log_error "RBAC再適用に失敗しました"
            log_error "手動での介入が必要かもしれません"
            return 1
        fi
    else
        log_info "[DRY RUN] コマンドを実行します: $RBAC_SCRIPT --auto"
    fi
}

# アップグレード後の検証
post_upgrade_verification() {
    log_step "アップグレード後の検証を実行しています..."
    
    # Dockerコンテナのチェック
    local containers=$(docker ps --filter "name=dify" --format "{{.Names}}" | wc -l)
    if [[ $containers -gt 0 ]]; then
        log_success "✓ Difyコンテナが実行中です ($containersコンテナ)"
    else
        log_error "✗ 実行中のDifyコンテナが見つかりません"
        return 1
    fi
    
    # RBAC検証
    if [[ "$SKIP_RBAC" != "true" && "$DRY_RUN" == "false" ]]; then
        if "$RBAC_SCRIPT" --verify-only >/dev/null 2>&1; then
            log_success "✓ RBAC設定が検証されました"
        else
            log_warning "⚠ RBAC検証に失敗しました"
            return 1
        fi
    fi
    
    # 基本的なヘルスチェック（コンテナが応答するかどうか）
    log_info "基本的なヘルスチェックを実行しています..."
    sleep 10
    
    if docker ps --filter "name=dify" --filter "status=running" | grep -q .; then
        log_success "✓ すべてのサービスが正常に動作しています"
    else
        log_warning "⚠ 一部のサービスが完全に準備されていない可能性があります"
    fi
    
    log_success "アップグレード後の検証が完了しました"
}

# アップグレードレポートの生成
generate_upgrade_report() {
    log_step "アップグレードレポートを生成しています..."
    
    local report_file="$BACKUP_DIR/upgrade_report.txt"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > "$report_file" << EOF
========================================
Dify統合アップグレードレポート
========================================

タイムスタンプ: $(date)
モード: $MODE
Difyルート: $DIFY_ROOT
RBACスクリプト: ${RBAC_SCRIPT:-"未使用"}
RBACスキップ: $SKIP_RBAC
バックアップディレクトリ: $BACKUP_DIR

完了したアップグレードステップ:
✓ アップグレード前の検証
✓ 設定バックアップ
$([ "$SKIP_RBAC" != "true" ] && echo "✓ RBACロールバック")
✓ Difyアップグレード (Git pull + Docker再起動)
$([ "$SKIP_RBAC" != "true" ] && echo "✓ RBAC再適用")
✓ アップグレード後の検証

現在のDockerコンテナ:
$(docker ps --filter "name=dify" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}")

Gitステータス:
$(cd "$DIFY_ROOT" && git log --oneline -5)

$([ "$SKIP_RBAC" != "true" ] && echo "RBACステータス:" && "$RBAC_SCRIPT" --verify-only 2>/dev/null | grep -E "(SUCCESS|✓)" || echo "RBAC検証はスキップまたは失敗しました")

バックアップの内容:
$(ls -la "$BACKUP_DIR")

次のステップ:
1. アプリケーションログを監視して問題がないか確認
2. 異なるユーザー権限で機能をテスト
3. このバックアップを次回の成功したアップグレードまで保持

ロールバック手順:
問題が発生した場合、バックアップから復元できます：
1. サービスを停止: cd $DIFY_ROOT/docker && docker compose down
2. 設定を復元: cp $BACKUP_DIR/*.bak ./
3. ボリュームを復元: tar -xzf $BACKUP_DIR/volumes-*.tgz
4. サービスを起動: docker compose up -d
$([ "$SKIP_RBAC" != "true" ] && echo "5. RBACを再適用: $RBAC_SCRIPT --auto")

========================================
EOF
        log_success "アップグレードレポートを生成しました: $report_file"
    else
        log_info "[DRY RUN] アップグレードレポートを生成します: $report_file"
    fi
}

# アクションの確認
confirm_action() {
    if [[ "$MODE" == "auto" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    echo
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Dify統合アップグレード概要${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "Difyルート: ${BLUE}$DIFY_ROOT${NC}"
    echo -e "RBACスクリプト: ${BLUE}${RBAC_SCRIPT:-"未使用"}${NC}"
    echo -e "RBACスキップ: ${BLUE}$SKIP_RBAC${NC}"
    echo -e "バックアップディレクトリ: ${BLUE}$BACKUP_DIR${NC}"
    echo
    echo -e "${YELLOW}このスクリプトは以下を実行します:${NC}"
    echo "1. 現在の設定とデータをバックアップ"
    [[ "$SKIP_RBAC" != "true" ]] && echo "2. RBAC設定を一時的にロールバック"
    echo "3. Difyを最新バージョンに更新"
    echo "4. すべてのDifyサービスを再起動"
    [[ "$SKIP_RBAC" != "true" ]] && echo "5. RBAC設定を再適用"
    echo "6. アップグレードが成功したことを確認"
    echo
    echo -n -e "${YELLOW}続行しますか？ (y/N): ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log_info "アップグレードがキャンセルされました"
            exit 0
            ;;
    esac
}

# メイン実行フロー
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║           Dify統合アップグレードスクリプト                 ║
║     Difyの更新をRBAC設定を保持しつつシームレスに行う        ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    parse_args "$@"
    
    [[ "$DRY_RUN" == "true" ]] && log_warning "DRY RUNモード - 変更は加えられません"
    
    detect_dify_directory
    detect_rbac_script
    setup_backup
    
    confirm_action
    
    # アップグレードステップを実行
    pre_upgrade_validation
    backup_configuration
    rbac_rollback
    dify_upgrade
    rbac_reapply
    post_upgrade_verification
    generate_upgrade_report
    
    echo
    log_success "🎉 Dify統合アップグレードが正常に完了しました！"
    echo
    echo -e "${GREEN}概要:${NC}"
    echo -e "  📂 バックアップ: ${BLUE}$BACKUP_DIR${NC}"
    echo -e "  🔧 Dify: ${GREEN}最新バージョンに更新${NC}"
    [[ "$SKIP_RBAC" != "true" ]] && echo -e "  🔐 RBAC: ${GREEN}保持され、検証済み${NC}"
    echo
    echo -e "${YELLOW}次のステップ:${NC}"
    echo "  1. ログを監視: docker compose logs -f"
    echo "  2. 異なるユーザー権限で機能をテスト"
    echo "  3. 次回の成功したアップグレードまでバックアップを保持"
    echo
    [[ "$DRY_RUN" == "false" ]] && echo -e "📊 完全レポート: ${BLUE}$BACKUP_DIR/upgrade_report.txt${NC}"
}

# スクリプト中断時のハンドリング
trap 'log_error "アップグレードが中断されました"; exit 1' INT TERM

# メイン関数を実行
main "$@"