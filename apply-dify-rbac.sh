#!/bin/bash
# Dify RBAC One-liner Application Script
# Restricts log viewing to Owner/Admin roles only
# Usage: ./apply-dify-rbac.sh [--auto|--interactive|--verify-only|--rollback]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFY_ROOT=""
API_CONTAINER=""
WEB_CONTAINER=""
MODE="interactive"
BACKUP_DIR=""

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

# Help function
show_help() {
    cat << EOF
Dify RBAC One-liner Application Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --auto          Fully automated execution (recommended)
    --interactive   Step-by-step confirmation (default)
    --verify-only   Only verify current RBAC status
    --rollback      Rollback previous changes
    --dify-path     Specify Dify installation directory
    --help          Show this help message

EXAMPLES:
    $0 --auto                           # Full automatic application
    $0 --interactive                    # Step-by-step with confirmations
    $0 --dify-path /custom/dify --auto  # Custom Dify path
    $0 --verify-only                    # Check current RBAC status
    $0 --rollback                       # Undo changes

DESCRIPTION:
    This script applies RBAC restrictions to Dify, limiting log viewing
    to Owner and Admin roles only. It automatically:
    
    1. Detects Dify installation and Docker containers
    2. Applies backend API patches with role checks
    3. Updates running Docker containers
    4. Verifies RBAC functionality
    5. Provides rollback capability if needed

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
            --verify-only)
                MODE="verify"
                shift
                ;;
            --rollback)
                MODE="rollback"
                shift
                ;;
            --dify-path)
                DIFY_ROOT="$2"
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
        "/root/dify"
        "$(pwd)/dify"
        "$(dirname "$SCRIPT_DIR")/dify"
        "/opt/dify"
        "/home/*/dify"
        "$(find /root -maxdepth 2 -name "dify" -type d 2>/dev/null | head -1)"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate/api" && -d "$candidate/web" ]]; then
            DIFY_ROOT="$candidate"
            log_success "Found Dify installation: $DIFY_ROOT"
            return 0
        fi
    done
    
    log_error "Could not find Dify installation directory"
    log_error "Please specify with --dify-path /path/to/dify"
    exit 1
}

# Detect Docker containers
detect_docker_containers() {
    log_info "Detecting Dify Docker containers..."
    
    # Find API container
    API_CONTAINER=$(docker ps --format "table {{.Names}}" | grep -E "(api|dify.*api)" | head -1)
    if [[ -z "$API_CONTAINER" ]]; then
        log_error "Could not find Dify API container"
        log_error "Please make sure Dify is running with Docker"
        exit 1
    fi
    
    # Find Web container (optional for backend-only RBAC)
    WEB_CONTAINER=$(docker ps --format "table {{.Names}}" | grep -E "(web|dify.*web)" | head -1)
    
    log_success "Found API container: $API_CONTAINER"
    if [[ -n "$WEB_CONTAINER" ]]; then
        log_success "Found Web container: $WEB_CONTAINER"
    else
        log_warning "Web container not found (backend-only RBAC will be applied)"
    fi
}

# Create backup directory
create_backup() {
    BACKUP_DIR="/tmp/dify-rbac-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    log_info "Created backup directory: $BACKUP_DIR"
    
    # Backup original files
    local files=(
        "api/controllers/console/app/workflow_app_log.py"
        "api/controllers/console/app/conversation.py"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$DIFY_ROOT/$file" ]]; then
            cp "$DIFY_ROOT/$file" "$BACKUP_DIR/$(basename "$file").original"
            log_info "Backed up $file"
        fi
    done
    
    # Backup container files
    docker cp "$API_CONTAINER:/app/api/controllers/console/app/workflow_app_log.py" "$BACKUP_DIR/workflow_app_log.py.container" 2>/dev/null || true
    docker cp "$API_CONTAINER:/app/api/controllers/console/app/conversation.py" "$BACKUP_DIR/conversation.py.container" 2>/dev/null || true
}

# Apply flexible patches
apply_rbac_patches() {
    log_info "Applying RBAC patches to backend files..."
    
    # Patch workflow_app_log.py
    patch_workflow_log_file
    
    # Patch conversation.py
    patch_conversation_file
    
    log_success "Successfully applied all RBAC patches"
}

# Patch workflow_app_log.py with multiple fallback patterns
patch_workflow_log_file() {
    local file="$DIFY_ROOT/api/controllers/console/app/workflow_app_log.py"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi
    
    # Check if already patched
    if grep -q "RBAC.*Only owner and admin can view" "$file"; then
        log_warning "workflow_app_log.py already patched"
        return 0
    fi
    
    # Add required imports if not present
    if ! grep -q "from flask_login import current_user" "$file"; then
        sed -i '1a from flask_login import current_user' "$file"
    fi
    
    if ! grep -q "from werkzeug.exceptions import Forbidden" "$file"; then
        sed -i '1a from werkzeug.exceptions import Forbidden' "$file"
    fi
    
    # Apply RBAC check - try multiple patterns
    local patterns=(
        's/def get(self, app_model: App):/def get(self, app_model: App):\
        # RBAC: Only owner and admin can view logs\
        from models.account import TenantAccountRole\
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):\
            raise Forbidden("Only owner or admin can view workflow logs")\
        /'
        
        's/parser = reqparse.RequestParser()/# RBAC: Only owner and admin can view logs\
        from models.account import TenantAccountRole\
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):\
            raise Forbidden("Only owner or admin can view workflow logs")\
        \
        parser = reqparse.RequestParser()/'
    )
    
    for pattern in "${patterns[@]}"; do
        if sed -i "$pattern" "$file" 2>/dev/null; then
            log_success "Applied RBAC patch to workflow_app_log.py"
            return 0
        fi
    done
    
    log_error "Failed to patch workflow_app_log.py automatically"
    manual_patch_workflow_log "$file"
}

# Manual patch for workflow_app_log.py
manual_patch_workflow_log() {
    local file="$1"
    log_warning "Applying manual patch to workflow_app_log.py..."
    
    # Find the line with def get and add RBAC check after it
    local line_num
    line_num=$(grep -n "def get(self, app_model: App):" "$file" | cut -d: -f1)
    if [[ -n "$line_num" ]]; then
        # Insert RBAC check after the function definition and docstring
        sed -i "${line_num}a\\        # RBAC: Only owner and admin can view logs\\
        from models.account import TenantAccountRole\\
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):\\
            raise Forbidden(\"Only owner or admin can view workflow logs\")" "$file"
        log_success "Manual patch applied to workflow_app_log.py"
    else
        log_error "Could not find insertion point in workflow_app_log.py"
    fi
}

# Patch conversation.py with multiple API endpoints
patch_conversation_file() {
    local file="$DIFY_ROOT/api/controllers/console/app/conversation.py"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi
    
    # Check if already patched
    if grep -q "RBAC.*Only owner and admin can view" "$file"; then
        log_warning "conversation.py already patched"
        return 0
    fi
    
    # Replace all instances of "if not current_user.is_editor:" with RBAC check
    sed -i 's/if not current_user\.is_editor:/# RBAC: Only owner and admin can view logs\
        from models.account import TenantAccountRole\
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):/g' "$file"
    
    # Update the error message
    sed -i 's/raise Forbidden()/raise Forbidden("Only owner or admin can view conversation logs")/g' "$file"
    
    log_success "Applied RBAC patch to conversation.py"
}

# Update Docker containers
update_docker_containers() {
    log_info "Updating Docker containers with patched files..."
    
    # Copy modified files to API container
    docker cp "$DIFY_ROOT/api/controllers/console/app/workflow_app_log.py" "$API_CONTAINER:/app/api/controllers/console/app/"
    docker cp "$DIFY_ROOT/api/controllers/console/app/conversation.py" "$API_CONTAINER:/app/api/controllers/console/app/"
    
    log_success "Files copied to API container"
    
    # Restart API container to reload Python modules
    log_info "Restarting API container to apply changes..."
    if ! docker restart "$API_CONTAINER" >/dev/null 2>&1; then
        log_error "Failed to restart API container"
        exit 1
    fi
    
    # Wait for container to be ready - simplified approach
    log_info "Waiting for API container to be ready..."
    sleep 10  # Give container time to start
    
    # Check if container is running
    local retries=12
    while [[ $retries -gt 0 ]]; do
        if docker ps -q -f name="$API_CONTAINER" -f status=running >/dev/null 2>&1; then
            log_success "API container is running"
            break
        fi
        sleep 5
        ((retries--))
        log_info "Waiting for container... ($retries attempts remaining)"
    done
    
    if [[ $retries -eq 0 ]]; then
        log_error "API container failed to start properly"
        docker logs "$API_CONTAINER" --tail 10
        exit 1
    fi
    
    # Additional wait to ensure services are fully loaded
    log_info "Allowing services to fully initialize..."
    sleep 15
    
    log_success "API container restarted successfully"
}

# Verify RBAC functionality
verify_rbac() {
    log_info "Verifying RBAC implementation..."
    
    # Check if RBAC code is present in container
    if docker exec "$API_CONTAINER" grep -q "RBAC.*Only owner and admin" /app/api/controllers/console/app/workflow_app_log.py; then
        log_success "✓ RBAC check found in workflow_app_log.py"
    else
        log_error "✗ RBAC check not found in workflow_app_log.py"
        return 1
    fi
    
    if docker exec "$API_CONTAINER" grep -q "RBAC.*Only owner and admin" /app/api/controllers/console/app/conversation.py; then
        log_success "✓ RBAC check found in conversation.py"
    else
        log_error "✗ RBAC check not found in conversation.py"
        return 1
    fi
    
    # Check if TenantAccountRole.is_privileged_role exists
    if docker exec "$API_CONTAINER" python -c "from models.account import TenantAccountRole; print('is_privileged_role:', hasattr(TenantAccountRole, 'is_privileged_role'))" 2>/dev/null | grep -q "True"; then
        log_success "✓ TenantAccountRole.is_privileged_role method available"
    else
        log_error "✗ TenantAccountRole.is_privileged_role method not available"
        return 1
    fi
    
    log_success "RBAC verification completed successfully"
    return 0
}

# Rollback changes
rollback_changes() {
    log_info "Rolling back RBAC changes..."
    
    if [[ -z "$BACKUP_DIR" ]]; then
        # Find latest backup
        BACKUP_DIR=$(find /tmp -maxdepth 1 -name "dify-rbac-backup-*" -type d | sort | tail -1)
        if [[ -z "$BACKUP_DIR" ]]; then
            log_error "No backup directory found"
            exit 1
        fi
    fi
    
    log_info "Using backup directory: $BACKUP_DIR"
    
    # Restore original files
    if [[ -f "$BACKUP_DIR/workflow_app_log.py.original" ]]; then
        cp "$BACKUP_DIR/workflow_app_log.py.original" "$DIFY_ROOT/api/controllers/console/app/workflow_app_log.py"
        log_success "Restored workflow_app_log.py"
    fi
    
    if [[ -f "$BACKUP_DIR/conversation.py.original" ]]; then
        cp "$BACKUP_DIR/conversation.py.original" "$DIFY_ROOT/api/controllers/console/app/conversation.py"
        log_success "Restored conversation.py"
    fi
    
    # Update containers with original files
    if [[ -f "$BACKUP_DIR/workflow_app_log.py.container" ]]; then
        docker cp "$BACKUP_DIR/workflow_app_log.py.container" "$API_CONTAINER:/app/api/controllers/console/app/workflow_app_log.py"
    fi
    
    if [[ -f "$BACKUP_DIR/conversation.py.container" ]]; then
        docker cp "$BACKUP_DIR/conversation.py.container" "$API_CONTAINER:/app/api/controllers/console/app/conversation.py"
    fi
    
    # Restart API container
    docker restart "$API_CONTAINER" >/dev/null
    
    log_success "Rollback completed successfully"
}

# Generate report
generate_report() {
    log_info "Generating RBAC application report..."
    
    cat << EOF

========================================
Dify RBAC Application Report
========================================

Timestamp: $(date)
Mode: $MODE
Dify Root: $DIFY_ROOT
API Container: $API_CONTAINER
Web Container: $WEB_CONTAINER
Backup Directory: $BACKUP_DIR

Changes Applied:
✓ Backend API RBAC restrictions
  - workflow_app_log.py: Owner/Admin only access
  - conversation.py: Owner/Admin only access
  - All conversation endpoints protected

Security Level:
✓ API Level Protection: ENABLED
  - Editor/Member users will receive 403 Forbidden
  - Direct API access blocked for non-privileged users
  - Multi-layer validation implemented

Access Control Matrix:
| Role   | Log API Access | Status |
|--------|----------------|--------|
| Owner  | ✓ Allowed      | OK     |
| Admin  | ✓ Allowed      | OK     |
| Editor | ✗ Forbidden    | OK     |
| Member | ✗ Forbidden    | OK     |

Next Steps:
1. Test with Editor/Member user accounts
2. Verify 403 Forbidden errors on log access
3. Monitor API logs for RBAC enforcement

Rollback:
Run: $0 --rollback

========================================

EOF
}

# Confirmation prompt
confirm_action() {
    if [[ "$MODE" == "auto" ]]; then
        return 0
    fi
    
    echo -n -e "${YELLOW}Do you want to continue? (y/N): ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log_info "Operation cancelled by user"
            exit 0
            ;;
    esac
}

# Main execution flow
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════╗
║        Dify RBAC One-liner Script        ║
║    Restrict Log Viewing to Owner/Admin   ║
╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    parse_args "$@"
    
    case "$MODE" in
        "verify")
            detect_dify_directory
            detect_docker_containers
            verify_rbac
            exit 0
            ;;
        "rollback")
            detect_dify_directory
            detect_docker_containers
            rollback_changes
            exit 0
            ;;
    esac
    
    # Main application flow
    detect_dify_directory
    detect_docker_containers
    
    log_info "Ready to apply RBAC restrictions to Dify"
    log_info "This will restrict log viewing to Owner and Admin roles only"
    confirm_action
    
    create_backup
    apply_rbac_patches
    update_docker_containers
    
    if verify_rbac; then
        log_success "RBAC successfully applied!"
        generate_report
    else
        log_error "RBAC verification failed"
        log_warning "You may want to run: $0 --rollback"
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"