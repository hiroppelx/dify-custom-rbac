#!/usr/bin/env node
/**
 * Dify Frontend RBAC Patch Script
 * This script patches Dify frontend to restrict log viewing to Owner/Admin roles only.
 */

const fs = require('fs');
const path = require('path');

// Define patches as [file_path, search_pattern, replacement]
const PATCHES = [
  // Patch 1: app-context.tsx - Add isCurrentWorkspacePrivileged property
  {
    file: 'web/context/app-context.tsx',
    search: `  isCurrentWorkspaceOwner: boolean
  isCurrentWorkspaceEditor: boolean`,
    replace: `  isCurrentWorkspaceOwner: boolean
  isCurrentWorkspacePrivileged: boolean
  isCurrentWorkspaceEditor: boolean`
  },
  
  // Patch 2: app-context.tsx - Add isCurrentWorkspacePrivileged computation
  {
    file: 'web/context/app-context.tsx',
    search: `  const isCurrentWorkspaceOwner = useMemo(() => currentWorkspace.role === 'owner', [currentWorkspace.role])
  const isCurrentWorkspaceEditor = useMemo(() => ['owner', 'admin', 'editor'].includes(currentWorkspace.role), [currentWorkspace.role])`,
    replace: `  const isCurrentWorkspaceOwner = useMemo(() => currentWorkspace.role === 'owner', [currentWorkspace.role])
  const isCurrentWorkspacePrivileged = useMemo(() => ['owner', 'admin'].includes(currentWorkspace.role), [currentWorkspace.role])
  const isCurrentWorkspaceEditor = useMemo(() => ['owner', 'admin', 'editor'].includes(currentWorkspace.role), [currentWorkspace.role])`
  },
  
  // Patch 3: app-context.tsx - Add to AppContext.Provider value
  {
    file: 'web/context/app-context.tsx',
    search: `      isCurrentWorkspaceManager,
      isCurrentWorkspaceOwner,
      isCurrentWorkspaceEditor,`,
    replace: `      isCurrentWorkspaceManager,
      isCurrentWorkspaceOwner,
      isCurrentWorkspacePrivileged,
      isCurrentWorkspaceEditor,`
  },
  
  // Patch 4: app-context.tsx - Add to default context value
  {
    file: 'web/context/app-context.tsx',
    search: `  isCurrentWorkspaceOwner: false,
  isCurrentWorkspaceEditor: false,`,
    replace: `  isCurrentWorkspaceOwner: false,
  isCurrentWorkspacePrivileged: false,
  isCurrentWorkspaceEditor: false,`
  },
  
  // Patch 5: layout-main.tsx - Import useAppContext properly
  {
    file: 'web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx',
    search: `  const { isCurrentWorkspaceEditor, isLoadingCurrentWorkspace, currentWorkspace } = useAppContext()`,
    replace: `  const { isCurrentWorkspaceEditor, isCurrentWorkspacePrivileged, isLoadingCurrentWorkspace, currentWorkspace } = useAppContext()`
  },
  
  // Patch 6: layout-main.tsx - Update getNavigations to use isCurrentWorkspacePrivileged for logs
  {
    file: 'web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx',
    search: `  const getNavigations = useCallback((appId: string, isCurrentWorkspaceEditor: boolean, mode: string) => {`,
    replace: `  const getNavigations = useCallback((appId: string, isCurrentWorkspaceEditor: boolean, isCurrentWorkspacePrivileged: boolean, mode: string) => {`
  },
  
  // Patch 7: layout-main.tsx - Update logs menu item to check isCurrentWorkspacePrivileged
  {
    file: 'web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx',
    search: `      ...(isCurrentWorkspaceEditor
        ? [{
          name: mode !== 'workflow'
            ? t('common.appMenus.logAndAnn')
            : t('common.appMenus.logs'),
          href: \`/app/\${appId}/logs\`,
          icon: RiFileList3Line,
          selectedIcon: RiFileList3Fill,
        }]
        : []
      ),`,
    replace: `      ...(isCurrentWorkspacePrivileged
        ? [{
          name: mode !== 'workflow'
            ? t('common.appMenus.logAndAnn')
            : t('common.appMenus.logs'),
          href: \`/app/\${appId}/logs\`,
          icon: RiFileList3Line,
          selectedIcon: RiFileList3Fill,
        }]
        : []
      ),`
  },
  
  // Patch 8: layout-main.tsx - Update getNavigations call
  {
    file: 'web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx',
    search: `      setNavigation(getNavigations(appId, isCurrentWorkspaceEditor, res.mode))`,
    replace: `      setNavigation(getNavigations(appId, isCurrentWorkspaceEditor, isCurrentWorkspacePrivileged, res.mode))`
  },
  
  // Patch 9: layout-main.tsx - Update redirection logic for logs
  {
    file: 'web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx',
    search: `    if (!canIEditApp && (pathname.endsWith('configuration') || pathname.endsWith('workflow') || pathname.endsWith('logs'))) {
      router.replace(\`/app/\${appId}/overview\`)
      return
    }`,
    replace: `    if (!canIEditApp && (pathname.endsWith('configuration') || pathname.endsWith('workflow'))) {
      router.replace(\`/app/\${appId}/overview\`)
      return
    }
    if (!isCurrentWorkspacePrivileged && pathname.endsWith('logs')) {
      router.replace(\`/app/\${appId}/overview\`)
      return
    }`
  }
];

function applyPatches(difyRoot = '/root/dify') {
  console.log('Applying frontend patches...');
  
  for (const patch of PATCHES) {
    const filePath = path.join(difyRoot, patch.file);
    
    // Backup original file
    const backupPath = filePath + '.backup';
    if (!fs.existsSync(backupPath)) {
      fs.copyFileSync(filePath, backupPath);
      console.log(`Backed up ${filePath} to ${backupPath}`);
    }
    
    // Read file content
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Apply patch
    if (content.includes(patch.search)) {
      content = content.replace(patch.search, patch.replace);
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`Patched ${filePath}`);
    } else {
      console.log(`WARNING: Search pattern not found in ${filePath}`);
    }
  }
}

function revertPatches(difyRoot = '/root/dify') {
  console.log('Reverting frontend patches...');
  
  for (const patch of PATCHES) {
    const filePath = path.join(difyRoot, patch.file);
    const backupPath = filePath + '.backup';
    
    if (fs.existsSync(backupPath)) {
      fs.copyFileSync(backupPath, filePath);
      console.log(`Reverted ${filePath}`);
      fs.unlinkSync(backupPath);
    } else {
      console.log(`No backup found for ${filePath}`);
    }
  }
}

// Main execution
const args = process.argv.slice(2);
if (args.includes('revert')) {
  revertPatches();
} else {
  applyPatches();
}