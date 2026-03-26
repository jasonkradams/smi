global class UpdateCalendarViewFiltersBatch implements Database.Batchable<sObject>, Database.Stateful {
  private Map<String, Id> newListViewIds = new Map<String, Id>();
  private Integer recordsUpdated = 0;
  private Integer recordsProcessed = 0;

  global Database.QueryLocator start(Database.BatchableContext bc) {
    // Build the new list view ID mapping
    for (ListView lv : [
      SELECT Id, Name
      FROM ListView
      WHERE SObjectType = 'Event_Registration__c' AND Name LIKE '%All'
      ORDER BY Name
    ]) {
      String key = lv.Name.replaceAll(' Events All', '').trim();
      newListViewIds.put(key, lv.Id);
    }

    System.debug(
      'Initialized with ' + newListViewIds.size() + ' list view mappings'
    );

    // Query all CalendarView records to update
    return Database.getQueryLocator(
      [
        SELECT Id, Name, ListViewFilterId
        FROM CalendarView
        WHERE SObjectType = 'Event_Registration__c'
      ]
    );
  }

  global void execute(Database.BatchableContext bc, List<CalendarView> scope) {
    List<CalendarView> toUpdate = new List<CalendarView>();

    for (CalendarView cv : scope) {
      recordsProcessed++;

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
          recordsUpdated++;
        }
      }
      System.debug('Batch: Updated ' + toUpdate.size() + ' records');
    }
  }

  global void finish(Database.BatchableContext bc) {
    System.debug('=== UpdateCalendarViewFiltersBatch Complete ===');
    System.debug('Total processed: ' + recordsProcessed);
    System.debug('Total updated: ' + recordsUpdated);
  }
}
