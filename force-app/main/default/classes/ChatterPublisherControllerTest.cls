/**
 * Test class for ChatterPublisherController
 * Tests posting to Chatter groups and error handling
 */
@IsTest
private class ChatterPublisherControllerTest {
  /**
   * Test setup - creates test data
   */
  @TestSetup
  static void setupTestData() {
    // Test data will be created in individual test methods as needed
    // to avoid conflicts with existing Chatter groups
  }

  /**
   * Helper method to get or create a test Chatter group
   */
  private static CollaborationGroup getOrCreateTestGroup(String groupName) {
    // Check if group already exists
    List<CollaborationGroup> existing = [
      SELECT Id, Name
      FROM CollaborationGroup
      WHERE Name = :groupName AND CollaborationType = 'Public'
      LIMIT 1
    ];

    if (!existing.isEmpty()) {
      return existing[0];
    }

    // Create new group with unique name to avoid duplicates
    String uniqueName = groupName + '_Test_' + DateTime.now().getTime();
    CollaborationGroup newGroup = new CollaborationGroup(
      Name = uniqueName,
      CollaborationType = 'Public',
      Description = 'Test group for ChatterPublisherController'
    );
    insert newGroup;

    return newGroup;
  }

  @IsTest
  static void testPostToChatter_Success() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    // Test content with HTML formatting
    String content = '<p>This is a test post with <b>bold</b> text.</p>';

    Test.startTest();
    String feedItemId = ChatterPublisherController.postToChatter(
      testGroup.Id,
      content
    );
    Test.stopTest();

    // Verify the method completed without exceptions
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostToChatter_WithRichContent() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    // Test content with various HTML elements
    String content =
      '<p>Test post with:</p>' +
      '<ul><li>Bullet point 1</li><li>Bullet point 2</li></ul>' +
      '<p>Some <i>italic</i> and <b>bold</b> text</p>';

    Test.startTest();
    String feedItemId = ChatterPublisherController.postToChatter(
      testGroup.Id,
      content
    );
    Test.stopTest();

    // Verify the method completed without exceptions
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostToChatter_NullGroupId() {
    String content = '<p>Test content</p>';

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postToChatter(null, content);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'Expected AuraHandledException for null group ID'
    );
  }

  @IsTest
  static void testPostToChatter_EmptyGroupId() {
    String content = '<p>Test content</p>';

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postToChatter('', content);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'Expected AuraHandledException for empty group ID'
    );
  }

  @IsTest
  static void testPostToChatter_NullContent() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postToChatter(testGroup.Id, null);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'Expected AuraHandledException for null content'
    );
  }

  @IsTest
  static void testPostToChatter_EmptyContent() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postToChatter(testGroup.Id, '');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'Expected AuraHandledException for empty content'
    );
  }

  @IsTest
  static void testPostToChatter_InvalidGroupId() {
    // Use a properly formatted but non-existent ID
    String invalidGroupId = '0F9000000000000AAA';
    String content = '<p>Test content</p>';

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postToChatter(invalidGroupId, content);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'Expected AuraHandledException for invalid group ID'
    );
  }

  @IsTest
  static void testPostToChatter_PlainText() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    // Test plain text content
    String content = 'This is plain text without any HTML tags.';

    Test.startTest();
    String feedItemId = ChatterPublisherController.postToChatter(
      testGroup.Id,
      content
    );
    Test.stopTest();

    // Verify the method completed without exceptions
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostToChatter_WithLineBreaks() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    // Test content with various line break formats
    String content = '<p>Line 1</p><p>Line 2</p><br>Line 3<br/>Line 4';

    Test.startTest();
    String feedItemId = ChatterPublisherController.postToChatter(
      testGroup.Id,
      content
    );
    Test.stopTest();

    // Verify the method completed without exceptions
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostToChatter_WithHtmlEntities() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    // Test content with HTML entities
    String content = '<p>Testing &amp; &lt;entities&gt; &quot;quotes&quot; &nbsp;</p>';

    Test.startTest();
    String feedItemId = ChatterPublisherController.postToChatter(
      testGroup.Id,
      content
    );
    Test.stopTest();

    // Verify the method completed without exceptions
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostToChatter_LongContent() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    // Test with longer content
    String content =
      '<p>This is a longer test post with multiple paragraphs.</p>' +
      '<p>Second paragraph with more text to simulate a real post.</p>' +
      '<ul><li>Point 1</li><li>Point 2</li><li>Point 3</li></ul>' +
      '<p>Final paragraph with conclusion.</p>';

    Test.startTest();
    String feedItemId = ChatterPublisherController.postToChatter(
      testGroup.Id,
      content
    );
    Test.stopTest();

    // Verify the method completed without exceptions
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostToChatter_SpecialCharacters() {
    // Get or create test group
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');

    // Test content with special characters
    String content = '<p>Testing special chars: !@#$%^&*()_+-=[]{}|;:,.<>?</p>';

    Test.startTest();
    String feedItemId = ChatterPublisherController.postToChatter(
      testGroup.Id,
      content
    );
    Test.stopTest();

    // Verify the method completed without exceptions
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostPollToChatter_Success() {
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');
    String question = 'What is your favorite activity?';
    List<String> choices = new List<String>{ 'Hiking', 'Climbing', 'Skiing' };

    Test.startTest();
    String feedItemId = ChatterPublisherController.postPollToChatter(
      testGroup.Id,
      question,
      choices
    );
    Test.stopTest();

    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }

  @IsTest
  static void testPostPollToChatter_NullGroupId() {
    List<String> choices = new List<String>{ 'A', 'B' };
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postPollToChatter(null, 'Question?', choices);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();
    System.assert(exceptionThrown, 'Expected AuraHandledException');
  }

  @IsTest
  static void testPostPollToChatter_BlankQuestion() {
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');
    List<String> choices = new List<String>{ 'A', 'B' };
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postPollToChatter(testGroup.Id, '', choices);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();
    System.assert(exceptionThrown, 'Expected AuraHandledException');
  }

  @IsTest
  static void testPostPollToChatter_TooFewChoices() {
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');
    List<String> choices = new List<String>{ 'Only one' };
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      ChatterPublisherController.postPollToChatter(
        testGroup.Id,
        'Question?',
        choices
      );
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();
    System.assert(exceptionThrown, 'Expected AuraHandledException');
  }

  @IsTest
  static void testPostPollToChatter_BlankChoicesFiltered() {
    CollaborationGroup testGroup = getOrCreateTestGroup('TestGroup');
    List<String> choices = new List<String>{ 'Choice 1', '  ', 'Choice 2' };
    Test.startTest();
    String feedItemId = ChatterPublisherController.postPollToChatter(
      testGroup.Id,
      'Question?',
      choices
    );
    Test.stopTest();
    System.assertNotEquals(null, feedItemId, 'Feed item ID should not be null');
  }
}
