// Script to identify Event Registration list views and update CalendarViewConfiguration records
// with their respective filtered list view IDs

// Step 1: Query all Event Registration list views ending in "All"
System.debug('=== STEP 1: Identifying Event Registration List Views ===');
List<ListView> eventListViews = [
    SELECT Id, Name, DeveloperName, SObjectType
    FROM ListView
    WHERE SObjectType = 'Event_Registration__c' AND Name LIKE '%All'
    ORDER BY Name
];

System.debug('Found ' + eventListViews.size() + ' Event Registration "All" list views:');
Map<String, Id> listViewMap = new Map<String, Id>();
for (ListView lv : eventListViews) {
    System.debug('  - ' + lv.Name + ' (' + lv.DeveloperName + '): ' + lv.Id);
    listViewMap.put(lv.Name.replaceAll(' Events All', '').trim(), lv.Id);
}

// Step 2: Query all CalendarViewConfiguration records
System.debug('\n=== STEP 2: Current CalendarViewConfiguration Records ===');
List<CalendarViewConfiguration__c> calendarConfigs = [
    SELECT Id, Name, Filtered_List_View_Id__c
    FROM CalendarViewConfiguration__c
    ORDER BY Name
];

System.debug('Found ' + calendarConfigs.size() + ' CalendarViewConfiguration records:');
for (CalendarViewConfiguration__c config : calendarConfigs) {
    System.debug('  - ' + config.Name + ': ' + config.Filtered_List_View_Id__c);
}

// Step 3: Create mapping and prepare updates
System.debug('\n=== STEP 3: Mapping Calendar Configs to List Views ===');
Map<String, CalendarViewConfiguration__c> configsByName = new Map<String, CalendarViewConfiguration__c>();
for (CalendarViewConfiguration__c config : calendarConfigs) {
    configsByName.put(config.Name, config);
}

List<CalendarViewConfiguration__c> recordsToUpdate = new List<CalendarViewConfiguration__c>();

for (String configName : configsByName.keySet()) {
    CalendarViewConfiguration__c config = configsByName.get(configName);

    // Find matching list view
    if (listViewMap.containsKey(configName)) {
        Id newListViewId = listViewMap.get(configName);
        String oldValue = config.Filtered_List_View_Id__c != null ? config.Filtered_List_View_Id__c : 'null';
        String newValue = newListViewId;

        // Only update if different
        if (oldValue != newValue) {
            System.debug('  ' + configName + ': ' + oldValue + ' → ' + newValue);
            config.Filtered_List_View_Id__c = newListViewId;
            recordsToUpdate.add(config);
        } else {
            System.debug('  ' + configName + ': No change needed (already: ' + newValue + ')');
        }
    } else {
        System.debug('  WARNING: No matching list view found for "' + configName + '"');
    }
}

// Step 4: Execute updates
System.debug('\n=== STEP 4: Updating Records ===');
if (recordsToUpdate.size() > 0) {
    try {
        update recordsToUpdate;
        System.debug('✓ Successfully updated ' + recordsToUpdate.size() + ' CalendarViewConfiguration records');
    } catch (Exception e) {
        System.debug('✗ ERROR updating records: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
    }
} else {
    System.debug('No updates needed - all records already have correct list view IDs');
}

// Step 5: Verify updates
System.debug('\n=== STEP 5: Verification ===');
List<CalendarViewConfiguration__c> updatedConfigs = [
    SELECT Id, Name, Filtered_List_View_Id__c
    FROM CalendarViewConfiguration__c
    ORDER BY Name
];

System.debug('Final state:');
for (CalendarViewConfiguration__c config : updatedConfigs) {
    System.debug('  - ' + config.Name + ': ' + config.Filtered_List_View_Id__c);
}

System.debug('\n=== COMPLETE ===');
