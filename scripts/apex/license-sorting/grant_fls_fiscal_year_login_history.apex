/**
 * Script to grant Field-Level Security (FLS) access to System Administrator profile
 * for all Fiscal_Year_Login_History__c fields.
 * 
 * This ensures System Administrators can read and edit all fields on the custom object.
 * Run this script in Anonymous Apex after deploying the custom object.
 */

System.debug('=== Granting FLS Access to Fiscal_Year_Login_History__c Fields ===');
System.debug('Start time: ' + DateTime.now());

// Get System Administrator Profile and its associated PermissionSet
Profile adminProfile = [
    SELECT Id, Name 
    FROM Profile 
    WHERE Name = 'System Administrator' 
    LIMIT 1
];

System.debug('System Administrator Profile ID: ' + adminProfile.Id);

// Get the PermissionSet associated with the Profile
PermissionSet profilePermSet = [
    SELECT Id, Name 
    FROM PermissionSet 
    WHERE ProfileId = :adminProfile.Id 
    LIMIT 1
];

System.debug('PermissionSet ID: ' + profilePermSet.Id);

// Get all fields for Fiscal_Year_Login_History__c
Map<String, Schema.SObjectField> fieldMap = Fiscal_Year_Login_History__c.sObjectType.getDescribe().fields.getMap();
System.debug('Total fields found: ' + fieldMap.size());

// Get existing field permissions as a map for easy lookup
Map<String, FieldPermissions> existingPermsMap = new Map<String, FieldPermissions>();
for (FieldPermissions fp : [
    SELECT Id, Field, SobjectType, PermissionsRead, PermissionsEdit 
    FROM FieldPermissions 
    WHERE ParentId = :profilePermSet.Id 
    AND SobjectType = 'Fiscal_Year_Login_History__c'
]) {
    existingPermsMap.put(fp.Field, fp);
    System.debug('  Existing permission: ' + fp.Field);
}

System.debug('Existing permissions: ' + existingPermsMap.size());

// Process all custom fields
List<FieldPermissions> permsToUpsert = new List<FieldPermissions>();
Integer created = 0;
Integer updated = 0;
Integer skipped = 0;

for (String fieldName : fieldMap.keySet()) {
    // Only process custom fields (those ending with __c)
    if (fieldName.endsWith('__c')) {
        // Get the exact API name from the field describe
        Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
        String exactApiName = fieldDesc.getName();
        String fullFieldName = 'Fiscal_Year_Login_History__c.' + exactApiName;
        
        FieldPermissions fp = existingPermsMap.get(fullFieldName);
        
        if (fp == null) {
            // Create new permission
            fp = new FieldPermissions();
            fp.ParentId = profilePermSet.Id;
            fp.SobjectType = 'Fiscal_Year_Login_History__c';
            fp.Field = fullFieldName;
            fp.PermissionsRead = true;
            fp.PermissionsEdit = true;
            permsToUpsert.add(fp);
            created++;
            System.debug('  Will create permission for: ' + fullFieldName);
        } else {
            // Update existing permission if needed
            Boolean needsUpdate = false;
            if (!fp.PermissionsRead) {
                fp.PermissionsRead = true;
                needsUpdate = true;
            }
            if (!fp.PermissionsEdit) {
                fp.PermissionsEdit = true;
                needsUpdate = true;
            }
            if (needsUpdate) {
                permsToUpsert.add(fp);
                updated++;
                System.debug('  Will update permission for: ' + fullFieldName);
            } else {
                skipped++;
                System.debug('  Permission already correct for: ' + fullFieldName);
            }
        }
    }
}

System.debug('Permissions to create: ' + created);
System.debug('Permissions to update: ' + updated);
System.debug('Permissions already correct: ' + skipped);

if (!permsToUpsert.isEmpty()) {
    try {
        upsert permsToUpsert;
        System.debug('SUCCESS: Processed ' + permsToUpsert.size() + ' field permissions (' + created + ' created, ' + updated + ' updated)');
    } catch (Exception e) {
        System.debug('ERROR: Failed to process field permissions: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        
        // Try individual inserts/updates to identify problematic fields
        System.debug('Attempting individual updates to identify problematic fields...');
        Integer successCount = 0;
        Integer failCount = 0;
        List<String> failedFields = new List<String>();
        
        for (FieldPermissions fp : permsToUpsert) {
            try {
                if (fp.Id == null) {
                    insert fp;
                    System.debug('  Created: ' + fp.Field);
                    successCount++;
                } else {
                    update fp;
                    System.debug('  Updated: ' + fp.Field);
                    successCount++;
                }
            } catch (Exception ex) {
                System.debug('  FAILED for ' + fp.Field + ': ' + ex.getMessage());
                failedFields.add(fp.Field);
                failCount++;
                
                // Check if this might be a DateTime field issue
                if (ex.getMessage().contains('restricted picklist')) {
                    System.debug('    Note: This field may require manual FLS configuration in Setup');
                }
            }
        }
        
        System.debug('Individual processing complete: ' + successCount + ' succeeded, ' + failCount + ' failed');
        if (!failedFields.isEmpty()) {
            System.debug('Failed fields that may need manual configuration:');
            for (String field : failedFields) {
                System.debug('  - ' + field);
            }
        }
    }
} else {
    System.debug('No permissions needed - all fields already have correct access');
}

System.debug('=== FLS Access Grant Complete ===');
System.debug('End time: ' + DateTime.now());
