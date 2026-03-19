@isTest
private class EventPublicStatusHelperTest {
  @isTest
  static void testIsEventPublic_True() {
    EventPublicStatusHelper.TEST_REGS = new List<Event_Registration__c>{
      new Event_Registration__c(Name = 'Test', Public__c = true)
    };
    Test.startTest();
    Boolean result = EventPublicStatusHelper.isEventPublic('fakeId');
    Test.stopTest();
    System.assertEquals(
      true,
      result,
      'Should return true when Public__c is true'
    );
  }

  @isTest
  static void testIsEventPublic_False() {
    EventPublicStatusHelper.TEST_REGS = new List<Event_Registration__c>{
      new Event_Registration__c(Name = 'Test', Public__c = false)
    };
    Test.startTest();
    Boolean result = EventPublicStatusHelper.isEventPublic('fakeId');
    Test.stopTest();
    System.assertEquals(
      false,
      result,
      'Should return false when Public__c is false'
    );
  }

  @isTest
  static void testIsEventPublic_EmptyResult() {
    EventPublicStatusHelper.TEST_REGS = new List<Event_Registration__c>();
    Test.startTest();
    Boolean result = EventPublicStatusHelper.isEventPublic('fakeId');
    Test.stopTest();
    System.assertEquals(
      false,
      result,
      'Should return false when no record found'
    );
  }

  @isTest
  static void testIsEventPublic_InvalidId() {
    Test.startTest();
    Boolean result = EventPublicStatusHelper.isEventPublic('notAnId');
    Test.stopTest();
    System.assertEquals(false, result, 'Should return false for invalid ID');
  }
}
