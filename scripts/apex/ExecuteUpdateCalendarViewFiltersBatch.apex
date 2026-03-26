// Execute the UpdateCalendarViewFiltersBatch job
Database.executeBatch(new UpdateCalendarViewFiltersBatch(), 1000);
System.debug('✓ Batch job queued: UpdateCalendarViewFiltersBatch');
