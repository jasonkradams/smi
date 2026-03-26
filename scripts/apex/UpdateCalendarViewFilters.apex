// Update CalendarView records to point to new "Events All" list views
// Processes in smaller batches to respect governor limits

System.debug('=== Building list view mapping ===');
Map<String, Id> newListViewIds = new Map<String, Id>();
for (ListView lv : [
    SELECT Id, Name
    FROM ListView
    WHERE SObjectType = 'Event_Registration__c' AND Name LIKE '%All'
    ORDER BY Name
]) {
    String key = lv.Name.replaceAll(' Events All', '').trim();
    newListViewIds.put(key, lv.Id);
    System.debug('  ' + key + ' → ' + lv.Id);
}

System.debug('\n=== Processing CalendarViews ===');
Integer batchSize = 500;
Integer offset = 0;
Integer totalUpdated = 0;

while (true) {
    List<CalendarView> batch = [
        SELECT Id, Name, ListViewFilterId
        FROM CalendarView
        WHERE SObjectType = 'Event_Registration__c'
        ORDER BY Id
        LIMIT :batchSize
        OFFSET :offset
    ];

    if (batch.isEmpty()) {
        break;
    }

    System.debug('Processing batch at offset ' + offset + ' (' + batch.size() + ' records)');

    List<CalendarView> toUpdate = new List<CalendarView>();
    for (CalendarView cv : batch) {
        if (newListViewIds.containsKey(cv.Name)) {
            Id newId = newListViewIds.get(cv.Name);
            if (cv.ListViewFilterId != newId) {
                cv.ListViewFilterId = newId;
                toUpdate.add(cv);
            }
        }
    }

    if (!toUpdate.isEmpty()) {
        Database.SaveResult[] results = Database.update(toUpdate, false);
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                totalUpdated++;
            }
        }
        System.debug('  Updated ' + toUpdate.size() + ' in this batch');
    }

    offset += batchSize;
}

System.debug('\n✓ COMPLETE: Updated ' + totalUpdated + ' CalendarView records');
