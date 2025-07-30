#!/bin/bash
# Dify Integrated Upgrade Script with RBAC Support
# 統合アップデートスクリプト（RBAC対応）
# Author: Dify RBAC Project
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFY_ROOT=""
RBAC_SCRIPT=""
BACKUP_ROOT=""
BACKUP_DIR=""
SKIP_RBAC="false"
DRY_RUN="false"
FORCE="false"
MODE="interactive"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Dify Integrated Upgrade Script with RBAC Support

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --auto              Fully automated execution
    --interactive       Step-by-step confirmation (default)
    --dry-run           Show what would be done without executing
    --skip-rbac         Skip RBAC operations (Dify upgrade only)
    --force             Force execution even if checks fail
    --dify-path PATH    Specify Dify installation directory
    --rbac-script PATH  Specify RBAC script path
    --backup-root PATH  Specify backup root directory
    --help              Show this help message

EXAMPLES:
    $0 --auto                                    # Full automated upgrade
    $0 --interactive                             # Step-by-step upgrade
    $0 --dry-run                                 # Preview changes
    $0 --skip-rbac --auto                        # Dify upgrade only
    $0 --dify-path /custom/dify --auto           # Custom Dify path

DESCRIPTION:
    This script performs a complete Dify upgrade with RBAC preservation:
    
    1. Pre-upgrade validation and backup
    2. RBAC rollback (if enabled)
    3. Dify upgrade (Git pull + Docker restart)
    4. RBAC re-application (if enabled)
    5. Post-upgrade verification
    6. Detailed reporting

RBAC Integration:
    - Automatically detects and uses apply-dify-rbac.sh
    - Preserves RBAC settings through Dify upgrades
    - Provides rollback capability if upgrade fails
    - Verifies RBAC functionality after upgrade

EOF
}

# Parse command line arguments
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
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Detect Dify installation directory
detect_dify_directory() {
    log_info "Detecting Dify installation directory..."
    
    if [[ -n "$DIFY_ROOT" && -d "$DIFY_ROOT" ]]; then
        log_success "Using specified Dify directory: $DIFY_ROOT"
        return 0
    fi
    
    # Common Dify installation paths
    local candidates=(
        "$HOME/dify"
        "/root/dify"
        "$(pwd)/dify"
        "/opt/dify"
        "$HOME/dify/docker"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            # Check if it's the docker subdirectory
            if [[ "$(basename "$candidate")" == "docker" ]] && [[ -f "$candidate/docker-compose.yaml" ]]; then
                DIFY_ROOT="$(dirname "$candidate")"
                log_success "Found Dify installation: $DIFY_ROOT (detected from docker directory)"
                return 0
            # Check if it's the main dify directory
            elif [[ -d "$candidate/docker" ]] && [[ -f "$candidate/docker/docker-compose.yaml" ]]; then
                DIFY_ROOT="$candidate"
                log_success "Found Dify installation: $DIFY_ROOT"
                return 0
            fi
        fi
    done
    
    log_error "Could not find Dify installation directory"
    log_error "Please specify with --dify-path /path/to/dify"
    exit 1
}

# Detect RBAC script
detect_rbac_script() {
    if [[ "$SKIP_RBAC" == "true" ]]; then
        log_info "RBAC operations will be skipped (--skip-rbac specified)"
        return 0
    fi
    
    log_info "Detecting RBAC script..."
    
    if [[ -n "$RBAC_SCRIPT" && -f "$RBAC_SCRIPT" ]]; then
        log_success "Using specified RBAC script: $RBAC_SCRIPT"
        return 0
    fi
    
    # Search for RBAC script
    local candidates=(
        "$SCRIPT_DIR/apply-dify-rbac.sh"
        "$(pwd)/apply-dify-rbac.sh"
        "$HOME/dify-custom-rbac/apply-dify-rbac.sh"
        "/root/dify-custom-rbac/apply-dify-rbac.sh"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" && -x "$candidate" ]]; then
            RBAC_SCRIPT="$candidate"
            log_success "Found RBAC script: $RBAC_SCRIPT"
            return 0
        fi
    done
    
    log_warning "RBAC script not found. RBAC operations will be skipped."
    log_warning "To enable RBAC support, ensure apply-dify-rbac.sh is available and executable."
    SKIP_RBAC="true"
}

# Setup backup directory
setup_backup() {
    if [[ -n "$BACKUP_ROOT" ]]; then
        local backup_root="$BACKUP_ROOT"
    else
        local backup_root="$HOME/dify_backups"
    fi
    
    BACKUP_DIR="$backup_root/$(date '+%Y-%m-%d-%H%M%S_%Z')"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_success "Created backup directory: $BACKUP_DIR"
    else
        log_info "[DRY RUN] Would create backup directory: $BACKUP_DIR"
    fi
}

# Pre-upgrade validation
pre_upgrade_validation() {
    log_step "Performing pre-upgrade validation..."
    
    # Check if we're in the right directory structure
    if [[ ! -d "$DIFY_ROOT/docker" ]]; then
        log_error "Invalid Dify directory structure: $DIFY_ROOT/docker not found"
        exit 1
    fi
    
    if [[ ! -f "$DIFY_ROOT/docker/docker-compose.yaml" ]]; then
        log_error "docker-compose.yaml not found in $DIFY_ROOT/docker"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        exit 1
    fi
    
    # Check if Dify containers are running
    if ! docker ps --format "{{.Names}}" | grep -E "(api|web)" >/dev/null; then
        if [[ "$FORCE" != "true" ]]; then
            log_error "Dify containers are not running. Use --force to continue anyway."
            exit 1
        else
            log_warning "Dify containers are not running, but --force specified. Continuing..."
        fi
    fi
    
    # Check Git status
    cd "$DIFY_ROOT"
    if [[ -d ".git" ]]; then
        local git_status=$(git status --porcelain 2>/dev/null || echo "error")
        if [[ "$git_status" != "" && "$git_status" != "error" ]]; then
            log_warning "Working directory has uncommitted changes:"
            git status --short
            if [[ "$FORCE" != "true" && "$MODE" != "auto" ]]; then
                read -p "Continue anyway? (y/N): " -r
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Upgrade cancelled by user"
                    exit 0
                fi
            fi
        fi
    fi
    
    log_success "Pre-upgrade validation completed"
}

# Backup current configuration
backup_configuration() {
    log_step "Backing up current configuration..."
    
    cd "$DIFY_ROOT/docker"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Backup docker-compose.yaml
        cp docker-compose.yaml "$BACKUP_DIR/docker-compose.yaml.$(date '+%Y-%m-%d-%H%M%S_%Z').bak"
        log_success "Backed up docker-compose.yaml"
        
        # Backup volumes directory
        if [[ -d "volumes" ]]; then
            log_info "Backing up volumes directory... (this may take a while)"
            tar -czf "$BACKUP_DIR/volumes-$(date '+%Y-%m-%d-%H%M%S_%Z').tgz" volumes
            log_success "Backed up volumes directory"
        fi
        
        # Backup .env file if exists
        if [[ -f ".env" ]]; then
            cp .env "$BACKUP_DIR/.env.$(date '+%Y-%m-%d-%H%M%S_%Z').bak"
            log_success "Backed up .env file"
        fi
        
        # Create backup manifest
        cat > "$BACKUP_DIR/backup_manifest.txt" << EOF
Dify Integrated Upgrade Backup
Created: $(date)
Dify Root: $DIFY_ROOT
RBAC Script: ${RBAC_SCRIPT:-"Not used"}
Skip RBAC: $SKIP_RBAC

Files backed up:
- docker-compose.yaml
$([ -d "volumes" ] && echo "- volumes/ directory")
$([ -f ".env" ] && echo "- .env file")

Docker containers before upgrade:
$(docker ps --filter "name=dify" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}")
EOF
        log_success "Created backup manifest"
    else
        log_info "[DRY RUN] Would backup docker-compose.yaml"
        log_info "[DRY RUN] Would backup volumes directory"
        [[ -f ".env" ]] && log_info "[DRY RUN] Would backup .env file"
    fi
}

# RBAC rollback
rbac_rollback() {
    if [[ "$SKIP_RBAC" == "true" ]]; then
        log_info "Skipping RBAC rollback (--skip-rbac specified)"
        return 0
    fi
    
    log_step "Rolling back RBAC configuration..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if "$RBAC_SCRIPT" --rollback; then
            log_success "RBAC rollback completed"
        else
            log_warning "RBAC rollback failed or not needed"
        fi
    else
        log_info "[DRY RUN] Would execute: $RBAC_SCRIPT --rollback"
    fi
}

# Dify upgrade
dify_upgrade() {
    log_step "Performing Dify upgrade..."
    
    cd "$DIFY_ROOT"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Get latest code from main branch
        log_info "Fetching latest code from GitHub..."
        git checkout main
        git pull origin main
        log_success "Updated to latest code"
        
        # Stop services
        log_info "Stopping Dify services..."
        cd docker
        docker compose down
        log_success "Services stopped"
        
        # Start services
        log_info "Starting Dify services..."
        docker compose up -d
        log_success "Services started"
        
        # Wait for services to be ready
        log_info "Waiting for services to initialize..."
        sleep 30
        
        # Check if containers are running
        local retries=12
        while [[ $retries -gt 0 ]]; do
            if docker ps --filter "name=dify" --format "{{.Names}}" | grep -E "(api|web)" >/dev/null; then
                log_success "Dify services are running"
                break
            fi
            sleep 10
            ((retries--))
            if [[ $retries -gt 0 ]]; then
                log_info "Still waiting for services... ($retries attempts remaining)"
            fi
        done
        
        if [[ $retries -eq 0 ]]; then
            log_error "Dify services failed to start properly"
            log_error "Check logs with: docker compose logs"
            exit 1
        fi
    else
        log_info "[DRY RUN] Would execute: git checkout main"
        log_info "[DRY RUN] Would execute: git pull origin main"
        log_info "[DRY RUN] Would execute: docker compose down"
        log_info "[DRY RUN] Would execute: docker compose up -d"
    fi
}

# RBAC re-application
rbac_reapply() {
    if [[ "$SKIP_RBAC" == "true" ]]; then
        log_info "Skipping RBAC re-application (--skip-rbac specified)"
        return 0
    fi
    
    log_step "Re-applying RBAC configuration..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if "$RBAC_SCRIPT" --auto; then
            log_success "RBAC re-application completed"
        else
            log_error "RBAC re-application failed"
            log_error "Manual intervention may be required"
            return 1
        fi
    else
        log_info "[DRY RUN] Would execute: $RBAC_SCRIPT --auto"
    fi
}

# Post-upgrade verification
post_upgrade_verification() {
    log_step "Performing post-upgrade verification..."
    
    # Check Docker containers
    local containers=$(docker ps --filter "name=dify" --format "{{.Names}}" | wc -l)
    if [[ $containers -gt 0 ]]; then
        log_success "✓ Dify containers are running ($containers containers)"
    else
        log_error "✗ No Dify containers found running"
        return 1
    fi
    
    # RBAC verification
    if [[ "$SKIP_RBAC" != "true" && "$DRY_RUN" == "false" ]]; then
        if "$RBAC_SCRIPT" --verify-only >/dev/null 2>&1; then
            log_success "✓ RBAC configuration verified"
        else
            log_warning "⚠ RBAC verification failed"
            return 1
        fi
    fi
    
    # Basic health check (if containers are responding)
    log_info "Performing basic health check..."
    sleep 10
    
    if docker ps --filter "name=dify" --filter "status=running" | grep -q .; then
        log_success "✓ All services appear healthy"
    else
        log_warning "⚠ Some services may not be fully ready"
    fi
    
    log_success "Post-upgrade verification completed"
}

# Generate upgrade report
generate_upgrade_report() {
    log_step "Generating upgrade report..."
    
    local report_file="$BACKUP_DIR/upgrade_report.txt"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > "$report_file" << EOF
========================================
Dify Integrated Upgrade Report
========================================

Timestamp: $(date)
Mode: $MODE
Dify Root: $DIFY_ROOT
RBAC Script: ${RBAC_SCRIPT:-"Not used"}
Skip RBAC: $SKIP_RBAC
Backup Directory: $BACKUP_DIR

Upgrade Steps Completed:
✓ Pre-upgrade validation
✓ Configuration backup
$([ "$SKIP_RBAC" != "true" ] && echo "✓ RBAC rollback")
✓ Dify upgrade (Git pull + Docker restart)
$([ "$SKIP_RBAC" != "true" ] && echo "✓ RBAC re-application")
✓ Post-upgrade verification

Current Docker Containers:
$(docker ps --filter "name=dify" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}")

Git Status:
$(cd "$DIFY_ROOT" && git log --oneline -5)

$([ "$SKIP_RBAC" != "true" ] && echo "RBAC Status:" && "$RBAC_SCRIPT" --verify-only 2>/dev/null | grep -E "(SUCCESS|✓)" || echo "RBAC verification skipped or failed")

Backup Contents:
$(ls -la "$BACKUP_DIR")

Next Steps:
1. Monitor application logs for any issues
2. Test core functionality with different user roles
3. Keep this backup until the next successful upgrade

Rollback Instructions:
If issues occur, you can restore from backup:
1. Stop services: cd $DIFY_ROOT/docker && docker compose down
2. Restore configuration: cp $BACKUP_DIR/*.bak ./
3. Restore volumes: tar -xzf $BACKUP_DIR/volumes-*.tgz
4. Start services: docker compose up -d
$([ "$SKIP_RBAC" != "true" ] && echo "5. Re-apply RBAC: $RBAC_SCRIPT --auto")

========================================
EOF
        log_success "Upgrade report generated: $report_file"
    else
        log_info "[DRY RUN] Would generate upgrade report at: $report_file"
    fi
}

# Confirmation prompt
confirm_action() {
    if [[ "$MODE" == "auto" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    echo
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Dify Integrated Upgrade Summary${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "Dify Root: ${BLUE}$DIFY_ROOT${NC}"
    echo -e "RBAC Script: ${BLUE}${RBAC_SCRIPT:-"Not used"}${NC}"
    echo -e "Skip RBAC: ${BLUE}$SKIP_RBAC${NC}"
    echo -e "Backup Directory: ${BLUE}$BACKUP_DIR${NC}"
    echo
    echo -e "${YELLOW}This will:${NC}"
    echo "1. Backup current configuration and data"
    [[ "$SKIP_RBAC" != "true" ]] && echo "2. Rollback RBAC settings temporarily"
    echo "3. Update Dify to the latest version"
    echo "4. Restart all Dify services"
    [[ "$SKIP_RBAC" != "true" ]] && echo "5. Re-apply RBAC settings"
    echo "6. Verify the upgrade was successful"
    echo
    echo -n -e "${YELLOW}Do you want to continue? (y/N): ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log_info "Upgrade cancelled by user"
            exit 0
            ;;
    esac
}

# Main execution flow
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║           Dify Integrated Upgrade Script                 ║
║     Seamless Dify Updates with RBAC Preservation        ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    parse_args "$@"
    
    [[ "$DRY_RUN" == "true" ]] && log_warning "DRY RUN MODE - No changes will be made"
    
    detect_dify_directory
    detect_rbac_script
    setup_backup
    
    confirm_action
    
    # Execute upgrade steps
    pre_upgrade_validation
    backup_configuration
    rbac_rollback
    dify_upgrade
    rbac_reapply
    post_upgrade_verification
    generate_upgrade_report
    
    echo
    log_success "🎉 Dify integrated upgrade completed successfully!"
    echo
    echo -e "${GREEN}Summary:${NC}"
    echo -e "  📂 Backup: ${BLUE}$BACKUP_DIR${NC}"
    echo -e "  🔧 Dify: ${GREEN}Updated to latest version${NC}"
    [[ "$SKIP_RBAC" != "true" ]] && echo -e "  🔐 RBAC: ${GREEN}Preserved and verified${NC}"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Monitor logs: docker compose logs -f"
    echo "  2. Test functionality with different user roles"
    echo "  3. Keep backup until next successful upgrade"
    echo
    [[ "$DRY_RUN" == "false" ]] && echo -e "📊 Full report: ${BLUE}$BACKUP_DIR/upgrade_report.txt${NC}"
}

# Handle script interruption
trap 'log_error "Upgrade interrupted"; exit 1' INT TERM

# Run main function
main "$@"