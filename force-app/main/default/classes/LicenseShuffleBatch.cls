/**
 * Batch class for optimizing Salesforce Community license usage.
 *
 * Uses a two-pass design:
 *   execute() — collection phase only. Accumulates all users and login counts.
 *               No DML, no license decisions.
 *   finish()  — action phase. Sees all users before making any decisions.
 *               Calculates keep list, updates licenses, enqueues audit logs.
 *
 * Assigns Premium licenses to users with >5 logins, up to a maximum of 475.
 * Protected users (Chairs and new users <90 days old) always keep Premium.
 *
 * Runs daily via LoginHistorySyncBatch.finish() → Database.executeBatch().
 * Uses Fiscal_Year_Login_History__c for full fiscal year (Feb 1 – Jan 31) counts.
 */
public class LicenseShuffleBatch implements Database.Batchable<sObject>, Database.Stateful {
  private static final Integer MAX_PREMIUM_LICENSES = 475;
  private static final Integer LOGIN_THRESHOLD = 5;
  private static final Integer NEW_USER_DAYS = 90;
  private static final String CHAIR_PROFILE = 'SM Community Plus Chair';
  private static final String PREMIUM_PROFILE = 'SM Community Plus Member';
  private static final String LOGIN_PROFILE = 'SM Community Plus Login';
  private static final String PREMIUM_LICENSE = 'Customer Community Plus';
  private static final String LOGIN_LICENSE = 'Customer Community Plus Login';

  // Stateful: populated across all execute() chunks, consumed once in finish()
  private Set<Id> protectedUserIds = new Set<Id>();
  private Map<Id, Integer> userLoginCounts = new Map<Id, Integer>();
  private Map<Id, User> allUsers = new Map<Id, User>();
  private String batchJobId;
  private DateTime fiscalYearStart; // computed once in start()

  // -------------------------------------------------------------------------
  // start() — compute fiscal year window, return query locator
  // -------------------------------------------------------------------------
  public Database.QueryLocator start(Database.BatchableContext bc) {
    batchJobId = bc.getJobId();
    System.debug('LicenseShuffleBatch: Starting batch job ' + batchJobId);

    Integer currentMonth = Date.today().month();
    Integer currentYear = Date.today().year();
    Date startDate;
    if (currentMonth >= 2 && currentMonth <= 4) {
      // Feb–Apr: first three months of fiscal year — use rolling 365 days
      startDate = Date.today().addDays(-365);
    } else if (currentMonth >= 5) {
      // May–Dec: current fiscal year begins Feb 1 of this year
      startDate = Date.newInstance(currentYear, 2, 1);
    } else {
      // Jan: fiscal year began Feb 1 of previous year
      startDate = Date.newInstance(currentYear - 1, 2, 1);
    }
    fiscalYearStart = DateTime.newInstance(
      startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    System.debug('LicenseShuffleBatch: Fiscal year start: ' + startDate);

    return Database.getQueryLocator(
      [
        SELECT Id, Profile.UserLicense.Name, Profile.Name, CreatedDate
        FROM User
        WHERE
          IsActive = TRUE
          AND Profile.UserLicense.Name IN (:PREMIUM_LICENSE, :LOGIN_LICENSE)
        ORDER BY Profile.UserLicense.Name, CreatedDate DESC
      ]
    );
  }

  // -------------------------------------------------------------------------
  // execute() — COLLECTION ONLY. No DML, no decisions.
  // -------------------------------------------------------------------------
  public void execute(Database.BatchableContext bc, List<sObject> scope) {
    if (scope == null || scope.isEmpty())
      return;

    Set<Id> chunkUserIds = new Set<Id>();
    for (sObject obj : scope) {
      User u = (User) obj;
      allUsers.put(u.Id, u);
      chunkUserIds.add(u.Id);
      if (u.Profile.Name == CHAIR_PROFILE || isNewUser(u.CreatedDate)) {
        protectedUserIds.add(u.Id);
      }
    }

    // One aggregate SOQL for the whole chunk — replaces the previous per-user COUNT() loop
    for (AggregateResult ar : [
      SELECT User__c uid, COUNT(Id) cnt
      FROM Fiscal_Year_Login_History__c
      WHERE User__c IN :chunkUserIds AND Login_Time__c >= :fiscalYearStart
      GROUP BY User__c
    ]) {
      userLoginCounts.put((Id) ar.get('uid'), (Integer) ar.get('cnt'));
    }
    // Users absent from results have 0 logins; map miss is handled as 0 in finish()
  }

  // -------------------------------------------------------------------------
  // finish() — ACTION PHASE. Full picture of all users available here.
  // -------------------------------------------------------------------------
  public void finish(Database.BatchableContext bc) {
    try {
      AsyncApexJob job = [
        SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
        FROM AsyncApexJob
        WHERE Id = :bc.getJobId()
      ];
      System.debug(
        'LicenseShuffleBatch: Completed — Status=' +
          job.Status +
          ' Items=' +
          job.JobItemsProcessed +
          '/' +
          job.TotalJobItems +
          ' Errors=' +
          job.NumberOfErrors
      );
    } catch (QueryException e) {
      System.debug(
        'LicenseShuffleBatch: Could not query job status: ' + e.getMessage()
      );
    }

    System.debug(
      'LicenseShuffleBatch: Total users collected: ' + allUsers.size()
    );
    System.debug(
      'LicenseShuffleBatch: Protected users: ' + protectedUserIds.size()
    );

    if (allUsers.isEmpty()) {
      System.debug('LicenseShuffleBatch: No users to process');
      return;
    }

    // Cache profile IDs — two SOQL queries total for this method
    Map<String, Id> profileIds = new Map<String, Id>();
    for (Profile p : [
      SELECT Id, Name
      FROM Profile
      WHERE Name IN (:PREMIUM_PROFILE, :LOGIN_PROFILE)
    ]) {
      profileIds.put(p.Name, p.Id);
    }

    Set<Id> premiumUsersToKeep = calculatePremiumUsersToKeep();

    List<User> usersToUpdate = new List<User>();
    List<License_Change_Log__c> changeLogs = new List<License_Change_Log__c>();

    for (User u : allUsers.values()) {
      if (protectedUserIds.contains(u.Id))
        continue;

      String currentLicense = u.Profile.UserLicense.Name;
      Integer loginCount = userLoginCounts.containsKey(u.Id)
        ? userLoginCounts.get(u.Id)
        : 0;

      if (
        currentLicense == PREMIUM_LICENSE && !premiumUsersToKeep.contains(u.Id)
      ) {
        usersToUpdate.add(
          new User(Id = u.Id, ProfileId = profileIds.get(LOGIN_PROFILE))
        );
        changeLogs.add(
          makeLog(
            u,
            PREMIUM_LICENSE,
            LOGIN_LICENSE,
            u.Profile.Name,
            LOGIN_PROFILE,
            loginCount,
            'Low usage'
          )
        );
      } else if (
        currentLicense == LOGIN_LICENSE && premiumUsersToKeep.contains(u.Id)
      ) {
        usersToUpdate.add(
          new User(Id = u.Id, ProfileId = profileIds.get(PREMIUM_PROFILE))
        );
        changeLogs.add(
          makeLog(
            u,
            LOGIN_LICENSE,
            PREMIUM_LICENSE,
            u.Profile.Name,
            PREMIUM_PROFILE,
            loginCount,
            'High usage'
          )
        );
      }
    }

    System.debug(
      'LicenseShuffleBatch: License changes planned: ' + usersToUpdate.size()
    );

    if (!usersToUpdate.isEmpty()) {
      try {
        update usersToUpdate;
        System.debug(
          'LicenseShuffleBatch: Updated ' + usersToUpdate.size() + ' users'
        );
      } catch (Exception e) {
        System.debug(
          'LicenseShuffleBatch: Error updating users: ' + e.getMessage()
        );
      }
    }

    if (!changeLogs.isEmpty()) {
      try {
        LicenseChangeLogQueueable q = new LicenseChangeLogQueueable(changeLogs);
        if (Test.isRunningTest()) {
          q.execute(new TestQueueableContext());
        } else {
          System.enqueueJob(q);
        }
        System.debug(
          'LicenseShuffleBatch: Change logs enqueued: ' + changeLogs.size()
        );
      } catch (Exception e) {
        System.debug(
          'LicenseShuffleBatch: Error enqueueing change logs: ' + e.getMessage()
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  private Boolean isNewUser(DateTime createdDate) {
    if (createdDate == null)
      return false;
    return createdDate.date().daysBetween(Date.today()) < NEW_USER_DAYS;
  }

  /**
   * Determine which users should hold Premium licenses (max 475).
   *
   * 1. Always include all protected users (Chairs and new users).
   * 2. Add non-protected users with >5 logins, sorted descending by login count.
   * 3. Stop when 475 slots are filled.
   */
  private Set<Id> calculatePremiumUsersToKeep() {
    // Start with protected users that actually appear in our user set
    Set<Id> usersToKeep = new Set<Id>();
    for (Id uid : protectedUserIds) {
      if (allUsers.containsKey(uid))
        usersToKeep.add(uid);
    }

    // Collect non-protected users who qualify (>5 logins)
    List<User> qualifying = new List<User>();
    for (User u : allUsers.values()) {
      if (!protectedUserIds.contains(u.Id)) {
        Integer cnt = userLoginCounts.containsKey(u.Id)
          ? userLoginCounts.get(u.Id)
          : 0;
        if (cnt > LOGIN_THRESHOLD)
          qualifying.add(u);
      }
    }

    // Sort descending by login count so highest-usage users get slots first
    qualifying.sort(new UserLoginCountComparator(userLoginCounts));

    Integer remaining = MAX_PREMIUM_LICENSES - usersToKeep.size();
    for (User u : qualifying) {
      if (remaining <= 0)
        break;
      usersToKeep.add(u.Id);
      remaining--;
    }

    System.debug(
      'LicenseShuffleBatch: Keep list — total: ' +
        usersToKeep.size() +
        ' protected: ' +
        protectedUserIds.size() +
        ' qualifying: ' +
        qualifying.size()
    );
    return usersToKeep;
  }

  private License_Change_Log__c makeLog(
    User u,
    String oldLic,
    String newLic,
    String oldProf,
    String newProf,
    Integer cnt,
    String reason
  ) {
    return new License_Change_Log__c(
      User__c = u.Id,
      Old_License__c = oldLic,
      New_License__c = newLic,
      Old_Profile__c = oldProf,
      New_Profile__c = newProf,
      Login_Count__c = cnt,
      Reason__c = reason,
      Changed_At__c = DateTime.now(),
      Batch_Job_Id__c = batchJobId
    );
  }

  private class TestQueueableContext implements QueueableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }
  }

  private class UserLoginCountComparator implements Comparator<User> {
    private Map<Id, Integer> counts;
    UserLoginCountComparator(Map<Id, Integer> counts) {
      this.counts = counts;
    }
    public Integer compare(User a, User b) {
      Integer ca = counts.containsKey(a.Id) ? counts.get(a.Id) : 0;
      Integer cb = counts.containsKey(b.Id) ? counts.get(b.Id) : 0;
      return ca > cb ? -1 : (ca < cb ? 1 : 0);
    }
  }
}
