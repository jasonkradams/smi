// Minimal class exposed to Experience Cloud guest users for public event status checks.
// Guest users have no access to EventParticipantRedirectHelper (by design, to prevent
// participant data leakage). This class provides only the boolean public-status check.
public without sharing class EventPublicStatusHelper {
  @testVisible
  static List<Event_Registration__c> TEST_REGS = null;

  @AuraEnabled(cacheable=true)
  public static Boolean isEventPublic(String eventRegistrationId) {
    try {
      List<Event_Registration__c> regs = TEST_REGS != null
        ? TEST_REGS
        : [
            SELECT Id, Public__c
            FROM Event_Registration__c
            WHERE Id = :eventRegistrationId
            LIMIT 1
          ];
      if (regs.isEmpty()) {
        return false;
      }
      return regs[0].Public__c == true;
    } catch (Exception e) {
      System.debug('Error checking event public status: ' + e.getMessage());
      return false;
    }
  }
}
