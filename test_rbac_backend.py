#!/usr/bin/env python3
"""
Backend RBAC Test Suite
Tests for Owner/Admin only log access restrictions
"""

import json
import pytest
from unittest.mock import Mock, patch
from werkzeug.exceptions import Forbidden

from models.account import TenantAccountRole


class TestWorkflowLogRBAC:
    """Test workflow log API RBAC restrictions"""
    
    def test_owner_can_access_workflow_logs(self):
        """Test that Owner role can access workflow logs"""
        from controllers.console.app.workflow_app_log import WorkflowAppLogApi
        
        # Mock current_user with owner role
        with patch('controllers.console.app.workflow_app_log.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.OWNER
            
            # Create API instance
            api = WorkflowAppLogApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Mock the service call
            with patch('controllers.console.app.workflow_app_log.WorkflowAppService') as mock_service:
                mock_service.return_value.get_paginate_workflow_app_logs.return_value = {
                    'data': [],
                    'total': 0
                }
                
                # Test should not raise Forbidden
                try:
                    result = api.get(mock_app)
                    assert result is not None
                except Forbidden:
                    pytest.fail("Owner should be able to access workflow logs")
    
    def test_admin_can_access_workflow_logs(self):
        """Test that Admin role can access workflow logs"""
        from controllers.console.app.workflow_app_log import WorkflowAppLogApi
        
        # Mock current_user with admin role
        with patch('controllers.console.app.workflow_app_log.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.ADMIN
            
            # Create API instance
            api = WorkflowAppLogApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Mock the service call
            with patch('controllers.console.app.workflow_app_log.WorkflowAppService') as mock_service:
                mock_service.return_value.get_paginate_workflow_app_logs.return_value = {
                    'data': [],
                    'total': 0
                }
                
                # Test should not raise Forbidden
                try:
                    result = api.get(mock_app)
                    assert result is not None
                except Forbidden:
                    pytest.fail("Admin should be able to access workflow logs")
    
    def test_editor_cannot_access_workflow_logs(self):
        """Test that Editor role cannot access workflow logs"""
        from controllers.console.app.workflow_app_log import WorkflowAppLogApi
        
        # Mock current_user with editor role
        with patch('controllers.console.app.workflow_app_log.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.EDITOR
            
            # Create API instance
            api = WorkflowAppLogApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Test should raise Forbidden
            with pytest.raises(Forbidden) as exc_info:
                api.get(mock_app)
            
            assert "Only owner or admin can view workflow logs" in str(exc_info.value)
    
    def test_normal_user_cannot_access_workflow_logs(self):
        """Test that Normal (Member) role cannot access workflow logs"""
        from controllers.console.app.workflow_app_log import WorkflowAppLogApi
        
        # Mock current_user with normal role
        with patch('controllers.console.app.workflow_app_log.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.NORMAL
            
            # Create API instance
            api = WorkflowAppLogApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Test should raise Forbidden
            with pytest.raises(Forbidden) as exc_info:
                api.get(mock_app)
            
            assert "Only owner or admin can view workflow logs" in str(exc_info.value)


class TestConversationLogRBAC:
    """Test conversation log API RBAC restrictions"""
    
    def test_owner_can_access_conversation_logs(self):
        """Test that Owner role can access conversation logs"""
        from controllers.console.app.conversation import CompletionConversationApi
        
        # Mock current_user with owner role
        with patch('controllers.console.app.conversation.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.OWNER
            
            # Create API instance
            api = CompletionConversationApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Mock the database call
            with patch('controllers.console.app.conversation.db') as mock_db:
                mock_db.paginate.return_value = Mock(items=[], total=0)
                mock_db.select.return_value.where.return_value.order_by.return_value = Mock()
                
                # Test should not raise Forbidden
                try:
                    result = api.get(mock_app)
                    assert result is not None
                except Forbidden:
                    pytest.fail("Owner should be able to access conversation logs")
    
    def test_admin_can_access_conversation_logs(self):
        """Test that Admin role can access conversation logs"""
        from controllers.console.app.conversation import CompletionConversationApi
        
        # Mock current_user with admin role
        with patch('controllers.console.app.conversation.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.ADMIN
            
            # Create API instance
            api = CompletionConversationApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Mock the database call
            with patch('controllers.console.app.conversation.db') as mock_db:
                mock_db.paginate.return_value = Mock(items=[], total=0)
                mock_db.select.return_value.where.return_value.order_by.return_value = Mock()
                
                # Test should not raise Forbidden
                try:
                    result = api.get(mock_app)
                    assert result is not None
                except Forbidden:
                    pytest.fail("Admin should be able to access conversation logs")
    
    def test_editor_cannot_access_conversation_logs(self):
        """Test that Editor role cannot access conversation logs"""
        from controllers.console.app.conversation import CompletionConversationApi
        
        # Mock current_user with editor role
        with patch('controllers.console.app.conversation.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.EDITOR
            
            # Create API instance
            api = CompletionConversationApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Test should raise Forbidden
            with pytest.raises(Forbidden) as exc_info:
                api.get(mock_app)
            
            assert "Only owner or admin can view conversation logs" in str(exc_info.value)
    
    def test_normal_user_cannot_access_conversation_logs(self):
        """Test that Normal (Member) role cannot access conversation logs"""
        from controllers.console.app.conversation import CompletionConversationApi
        
        # Mock current_user with normal role
        with patch('controllers.console.app.conversation.current_user') as mock_user:
            mock_user.current_tenant_account.role = TenantAccountRole.NORMAL
            
            # Create API instance
            api = CompletionConversationApi()
            
            # Mock app_model
            mock_app = Mock()
            mock_app.id = 'test-app-id'
            
            # Test should raise Forbidden
            with pytest.raises(Forbidden) as exc_info:
                api.get(mock_app)
            
            assert "Only owner or admin can view conversation logs" in str(exc_info.value)


class TestTenantAccountRole:
    """Test TenantAccountRole utility methods"""
    
    def test_is_privileged_role_owner(self):
        """Test that Owner is considered privileged"""
        assert TenantAccountRole.is_privileged_role(TenantAccountRole.OWNER) is True
    
    def test_is_privileged_role_admin(self):
        """Test that Admin is considered privileged"""
        assert TenantAccountRole.is_privileged_role(TenantAccountRole.ADMIN) is True
    
    def test_is_privileged_role_editor(self):
        """Test that Editor is not considered privileged"""
        assert TenantAccountRole.is_privileged_role(TenantAccountRole.EDITOR) is False
    
    def test_is_privileged_role_normal(self):
        """Test that Normal is not considered privileged"""
        assert TenantAccountRole.is_privileged_role(TenantAccountRole.NORMAL) is False
    
    def test_is_privileged_role_none(self):
        """Test that None is not considered privileged"""
        assert TenantAccountRole.is_privileged_role(None) is False


if __name__ == '__main__':
    # Run tests with pytest
    pytest.main([__file__, '-v'])