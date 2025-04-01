@isTest
private class CalendarControllerTest {
    
    @isTest
    static void testGetCalendars() {
        // Call the method to test
        Test.startTest();
        List<CalendarController.CalendarWrapper> calendars = CalendarController.getCalendars();
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, calendars, 'Calendars should not be null');
        System.assertEquals(3, calendars.size(), 'Should return 3 calendars');
        
        // Verify the first calendar
        CalendarController.CalendarWrapper workCalendar = calendars[0];
        System.assertEquals('cal1', workCalendar.id, 'First calendar ID should be cal1');
        System.assertEquals('Work Calendar', workCalendar.name, 'First calendar name should be Work Calendar');
        System.assertEquals('#1589EE', workCalendar.color, 'First calendar color should be #1589EE');
        
        // Verify the second calendar
        CalendarController.CalendarWrapper personalCalendar = calendars[1];
        System.assertEquals('cal2', personalCalendar.id, 'Second calendar ID should be cal2');
        System.assertEquals('Personal Calendar', personalCalendar.name, 'Second calendar name should be Personal Calendar');
        System.assertEquals('#4BC076', personalCalendar.color, 'Second calendar color should be #4BC076');
        
        // Verify the third calendar
        CalendarController.CalendarWrapper teamCalendar = calendars[2];
        System.assertEquals('cal3', teamCalendar.id, 'Third calendar ID should be cal3');
        System.assertEquals('Team Calendar', teamCalendar.name, 'Third calendar name should be Team Calendar');
        System.assertEquals('#F88962', teamCalendar.color, 'Third calendar color should be #F88962');
    }
    
    @isTest
    static void testGetEventsAllCalendars() {
        // Setup test data
        Date startDate = Date.today();
        Date endDate = startDate.addDays(30);
        List<String> calendarIds = new List<String>{'cal1', 'cal2', 'cal3'};
        
        // Call the method to test
        Test.startTest();
        List<CalendarController.EventWrapper> events = CalendarController.getEvents(startDate, endDate, calendarIds);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, events, 'Events should not be null');
        System.assertEquals(6, events.size(), 'Should return 6 events for all calendars');
        
        // Verify events from different calendars are present
        Set<String> calendarIdsInEvents = new Set<String>();
        for (CalendarController.EventWrapper event : events) {
            calendarIdsInEvents.add(event.calendarId);
        }
        
        System.assertEquals(3, calendarIdsInEvents.size(), 'Events from all 3 calendars should be present');
        System.assert(calendarIdsInEvents.contains('cal1'), 'Events from cal1 should be present');
        System.assert(calendarIdsInEvents.contains('cal2'), 'Events from cal2 should be present');
        System.assert(calendarIdsInEvents.contains('cal3'), 'Events from cal3 should be present');
    }
    
    @isTest
    static void testGetEventsSingleCalendar() {
        // Setup test data
        Date startDate = Date.today();
        Date endDate = startDate.addDays(30);
        List<String> calendarIds = new List<String>{'cal1'};
        
        // Call the method to test
        Test.startTest();
        List<CalendarController.EventWrapper> events = CalendarController.getEvents(startDate, endDate, calendarIds);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, events, 'Events should not be null');
        System.assertEquals(2, events.size(), 'Should return 2 events for cal1');
        
        // Verify all events are from cal1
        for (CalendarController.EventWrapper event : events) {
            System.assertEquals('cal1', event.calendarId, 'Event should be from cal1');
            System.assertEquals('Work Calendar', event.calendarName, 'Event should be from Work Calendar');
            System.assertEquals('#1589EE', event.color, 'Event color should be #1589EE');
        }
    }
    
    @isTest
    static void testGetEventsNoCalendars() {
        // Setup test data
        Date startDate = Date.today();
        Date endDate = startDate.addDays(30);
        List<String> calendarIds = new List<String>();
        
        // Call the method to test
        Test.startTest();
        List<CalendarController.EventWrapper> events = CalendarController.getEvents(startDate, endDate, calendarIds);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, events, 'Events should not be null');
        System.assertEquals(0, events.size(), 'Should return 0 events when no calendars are selected');
    }
    
    @isTest
    static void testCreateEvent() {
        // Setup test data
        String title = 'Test Event';
        Date startDate = Date.today();
        Date endDate = startDate.addDays(1);
        String calendarId = 'cal1';
        
        // Call the method to test
        Test.startTest();
        String eventId = CalendarController.createEvent(title, startDate, endDate, calendarId);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, eventId, 'Event ID should not be null');
        System.assert(eventId.startsWith('new-event-'), 'Event ID should start with new-event-');
    }
    
    @isTest
    static void testCalendarWrapperConstructor() {
        // Test the CalendarWrapper constructor
        String id = 'test-cal';
        String name = 'Test Calendar';
        String color = '#FF0000';
        
        Test.startTest();
        CalendarController.CalendarWrapper wrapper = new CalendarController.CalendarWrapper(id, name, color);
        Test.stopTest();
        
        // Verify the wrapper properties
        System.assertEquals(id, wrapper.id, 'Calendar ID should match');
        System.assertEquals(name, wrapper.name, 'Calendar name should match');
        System.assertEquals(color, wrapper.color, 'Calendar color should match');
    }
    
    @isTest
    static void testEventWrapperConstructor() {
        // Test the EventWrapper constructor
        String id = 'test-event';
        String title = 'Test Event';
        Date startDate = Date.today();
        Date endDate = startDate.addDays(1);
        String calendarId = 'test-cal';
        String calendarName = 'Test Calendar';
        String color = '#FF0000';
        
        Test.startTest();
        CalendarController.EventWrapper wrapper = new CalendarController.EventWrapper(
            id, title, startDate, endDate, calendarId, calendarName, color
        );
        Test.stopTest();
        
        // Verify the wrapper properties
        System.assertEquals(id, wrapper.id, 'Event ID should match');
        System.assertEquals(title, wrapper.title, 'Event title should match');
        System.assertEquals(startDate, wrapper.startDate, 'Event start date should match');
        System.assertEquals(endDate, wrapper.endDate, 'Event end date should match');
        System.assertEquals(calendarId, wrapper.calendarId, 'Event calendar ID should match');
        System.assertEquals(calendarName, wrapper.calendarName, 'Event calendar name should match');
        System.assertEquals(color, wrapper.color, 'Event color should match');
    }
}

