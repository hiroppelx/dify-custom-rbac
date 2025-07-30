#!/usr/bin/env python3
"""
Dify Backend RBAC Patch Script
This script patches Dify backend to restrict log viewing to Owner/Admin roles only.
"""

import os
import shutil
from pathlib import Path

# Define patches as (file_path, search_pattern, replacement)
PATCHES = [
    # Patch 1: workflow_app_log.py - Add import
    {
        'file': 'api/controllers/console/app/workflow_app_log.py',
        'search': '''from flask_restful import Resource, marshal_with, reqparse
from flask_restful.inputs import int_range
from sqlalchemy.orm import Session''',
        'replace': '''from flask_login import current_user
from flask_restful import Resource, marshal_with, reqparse
from flask_restful.inputs import int_range
from sqlalchemy.orm import Session
from werkzeug.exceptions import Forbidden'''
    },
    
    # Patch 2: workflow_app_log.py - Add role check
    {
        'file': 'api/controllers/console/app/workflow_app_log.py',
        'search': '''    def get(self, app_model: App):
        """
        Get workflow app logs
        """
        parser = reqparse.RequestParser()''',
        'replace': '''    def get(self, app_model: App):
        """
        Get workflow app logs
        """
        # RBAC: Only owner and admin can view logs
        from models.account import TenantAccountRole
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
            raise Forbidden("Only owner or admin can view workflow logs")
        
        parser = reqparse.RequestParser()'''
    },
    
    # Patch 3: conversation.py - CompletionConversationApi
    {
        'file': 'api/controllers/console/app/conversation.py',
        'search': '''    def get(self, app_model):
        if not current_user.is_editor:
            raise Forbidden()''',
        'replace': '''    def get(self, app_model):
        # RBAC: Only owner and admin can view logs
        from models.account import TenantAccountRole
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
            raise Forbidden("Only owner or admin can view conversation logs")'''
    },
    
    # Patch 4: conversation.py - CompletionConversationDetailApi.get
    {
        'file': 'api/controllers/console/app/conversation.py',
        'search': '''    def get(self, app_model, conversation_id):
        if not current_user.is_editor:
            raise Forbidden()''',
        'replace': '''    def get(self, app_model, conversation_id):
        # RBAC: Only owner and admin can view logs
        from models.account import TenantAccountRole
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
            raise Forbidden("Only owner or admin can view conversation logs")'''
    },
    
    # Patch 5: conversation.py - ChatConversationApi
    {
        'file': 'api/controllers/console/app/conversation.py',
        'search': '''    @marshal_with(conversation_with_summary_pagination_fields)
    def get(self, app_model):
        if not current_user.is_editor:
            raise Forbidden()''',
        'replace': '''    @marshal_with(conversation_with_summary_pagination_fields)
    def get(self, app_model):
        # RBAC: Only owner and admin can view logs
        from models.account import TenantAccountRole
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
            raise Forbidden("Only owner or admin can view conversation logs")'''
    },
    
    # Patch 6: conversation.py - ChatConversationDetailApi.get
    {
        'file': 'api/controllers/console/app/conversation.py',
        'search': '''    @marshal_with(conversation_detail_fields)
    def get(self, app_model, conversation_id):
        if not current_user.is_editor:
            raise Forbidden()''',
        'replace': '''    @marshal_with(conversation_detail_fields)
    def get(self, app_model, conversation_id):
        # RBAC: Only owner and admin can view logs
        from models.account import TenantAccountRole
        if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
            raise Forbidden("Only owner or admin can view conversation logs")'''
    }
]

def apply_patches(dify_root='/root/dify'):
    """Apply all patches to Dify backend files"""
    for patch in PATCHES:
        file_path = Path(dify_root) / patch['file']
        
        # Backup original file
        backup_path = file_path.with_suffix('.backup')
        if not backup_path.exists():
            shutil.copy2(file_path, backup_path)
            print(f"Backed up {file_path} to {backup_path}")
        
        # Read file content
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Apply patch
        if patch['search'] in content:
            content = content.replace(patch['search'], patch['replace'])
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Patched {file_path}")
        else:
            print(f"WARNING: Search pattern not found in {file_path}")

def revert_patches(dify_root='/root/dify'):
    """Revert all patches by restoring backup files"""
    for patch in PATCHES:
        file_path = Path(dify_root) / patch['file']
        backup_path = file_path.with_suffix('.backup')
        
        if backup_path.exists():
            shutil.copy2(backup_path, file_path)
            print(f"Reverted {file_path}")
            backup_path.unlink()
        else:
            print(f"No backup found for {file_path}")

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == 'revert':
        revert_patches()
    else:
        apply_patches()