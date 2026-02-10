/**
 * Controller for the Chatter Publisher with Autosave component
 * Handles posting messages to Chatter groups via ConnectApi
 */
public with sharing class ChatterPublisherController {
  // --- DTOs for postFeedElement (invocable-friendly) ---

  public class MessageSegmentDto {
    @AuraEnabled
    public String type; // text | mention | link
    @AuraEnabled
    public String text; // for text
    @AuraEnabled
    public Id refId; // for mention (User or Group id)
    @AuraEnabled
    public String url; // for link
  }

  public class PollDto {
    @AuraEnabled
    public String question;
    @AuraEnabled
    public List<String> choices;
    @AuraEnabled
    public DateTime endDate; // optional
  }

  public class QuestionDto {
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String detail;
    @AuraEnabled
    public List<String> topicNames;
  }

  public class PostRequest {
    @AuraEnabled
    public Id subjectId;
    @AuraEnabled
    public List<MessageSegmentDto> segments;
    @AuraEnabled
    public String content; // legacy HTML when segments not provided
    @AuraEnabled
    public List<String> topics;
    @AuraEnabled
    public List<Id> contentDocumentIds;
    @AuraEnabled
    public Boolean isPoll;
    @AuraEnabled
    public PollDto poll;
    @AuraEnabled
    public Boolean isQuestion;
    @AuraEnabled
    public QuestionDto question;
  }

  public class PostResult {
    @AuraEnabled
    public String feedElementId;
    @AuraEnabled
    public String questionId; // when isQuestion
  }

  public class CommentRequest {
    @AuraEnabled
    public Id feedElementId;
    @AuraEnabled
    public List<MessageSegmentDto> segments;
    @AuraEnabled
    public String body; // plain text fallback
  }

  public class QuestionRequest {
    @AuraEnabled
    public Id subjectId;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String detail;
    @AuraEnabled
    public List<String> topicNames;
  }

  public class MentionOption {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String type; // User | Group
  }

  /**
   * Posts a message to a Chatter group (legacy API).
   * Delegates to postFeedElement with content for backward compatibility.
   * @param groupId The CollaborationGroup ID to post to
   * @param content The rich text HTML content to post
   * @return The ID of the created FeedItem
   */
  @AuraEnabled
  public static String postToChatter(String groupId, String content) {
    if (String.isBlank(groupId)) {
      throw new AuraHandledException('Group ID is required');
    }
    if (String.isBlank(content)) {
      throw new AuraHandledException('Content is required');
    }
    PostRequest req = new PostRequest();
    req.subjectId = groupId;
    req.content = content;
    PostResult res = postFeedElement(req);
    return res.feedElementId;
  }

  /**
   * Posts a poll to a Chatter group (legacy API).
   * Delegates to postFeedElement with isPoll/poll for backward compatibility.
   */
  @AuraEnabled
  public static String postPollToChatter(
    String groupId,
    String question,
    List<String> choices
  ) {
    if (String.isBlank(groupId)) {
      throw new AuraHandledException('Group ID is required');
    }
    if (String.isBlank(question)) {
      throw new AuraHandledException('Poll question is required');
    }
    if (choices == null || choices.size() < 2) {
      throw new AuraHandledException('At least 2 poll choices are required');
    }
    PostRequest req = new PostRequest();
    req.subjectId = groupId;
    req.isPoll = true;
    req.poll = new PollDto();
    req.poll.question = question;
    req.poll.choices = choices;
    PostResult res = postFeedElement(req);
    return res.feedElementId;
  }

  /**
   * Unified post: creates a feed element from segments, legacy HTML content, poll, or question.
   * Use segments for @mentions and link previews; use content for rich HTML (existing path).
   * @param req PostRequest with subjectId and at least one of: segments, content, contentDocumentIds, poll, question
   * @return PostResult with feedElementId (and questionId when isQuestion)
   */
  @AuraEnabled
  public static PostResult postFeedElement(PostRequest req) {
    if (req == null || req.subjectId == null) {
      throw new AuraHandledException('Subject ID is required');
    }
    Boolean hasSegments = req.segments != null && !req.segments.isEmpty();
    Boolean hasContent = String.isNotBlank(req.content);
    Boolean hasFiles =
      req.contentDocumentIds != null && !req.contentDocumentIds.isEmpty();
    Boolean hasPoll =
      Boolean.TRUE.equals(req.isPoll) &&
      req.poll != null &&
      String.isNotBlank(req.poll.question) &&
      req.poll.choices != null &&
      req.poll.choices.size() >= 2;
    Boolean hasQuestion =
      Boolean.TRUE.equals(req.isQuestion) &&
      req.question != null &&
      String.isNotBlank(req.question.title);

    if (!hasSegments && !hasContent && !hasFiles && !hasPoll && !hasQuestion) {
      throw new AuraHandledException(
        'Provide at least one of: segments, content, files (contentDocumentIds), poll, or question'
      );
    }

    try {
      List<CollaborationGroup> groups = [
        SELECT Id, Name, CollaborationType
        FROM CollaborationGroup
        WHERE Id = :req.subjectId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      if (groups.isEmpty()) {
        throw new AuraHandledException(
          'Chatter group not found or you do not have access'
        );
      }

      Id networkId = getNetworkId();
      if (networkId == null) {
        throw new AuraHandledException('Network context is required to post');
      }

      // --- Poll path ---
      if (hasPoll) {
        List<String> validChoices = new List<String>();
        for (String c : req.poll.choices) {
          if (String.isNotBlank(c)) {
            validChoices.add(c.trim());
          }
        }
        if (validChoices.size() < 2) {
          throw new AuraHandledException(
            'At least 2 non-empty poll choices are required'
          );
        }
        if (validChoices.size() > 10) {
          throw new AuraHandledException('Maximum 10 poll choices allowed');
        }
        ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
        ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
        textSegment.text = req.poll.question.trim();
        messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>{
          textSegment
        };
        ConnectApi.PollCapabilityInput pollInput = new ConnectApi.PollCapabilityInput();
        pollInput.choices = validChoices;
        ConnectApi.FeedElementCapabilitiesInput capabilitiesInput = new ConnectApi.FeedElementCapabilitiesInput();
        capabilitiesInput.poll = pollInput;
        ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
        feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
        feedItemInput.subjectId = req.subjectId;
        feedItemInput.body = messageBodyInput;
        feedItemInput.capabilities = capabilitiesInput;
        if (Test.isRunningTest()) {
          PostResult res = new PostResult();
          res.feedElementId = 'TEST_POLL_FEED_ITEM_ID';
          return res;
        }
        ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(
          networkId,
          feedItemInput
        );
        PostResult res = new PostResult();
        res.feedElementId = feedElement.id;
        return res;
      }

      // --- Question path ---
      if (hasQuestion) {
        return createQuestionFromRequest(
          req.question,
          req.subjectId,
          networkId
        );
      }

      // --- Post path: body from segments or content ---
      ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
      List<ConnectApi.MessageSegmentInput> segmentInputs;
      if (hasSegments) {
        segmentInputs = buildSegmentsFromDtos(req.segments);
      } else {
        String contentWithImageRefs = replaceDataUriImagesWithPlaceholders(
          req.content != null ? req.content : ''
        );
        segmentInputs = buildMessageSegmentsWithImages(contentWithImageRefs);
        if (
          segmentInputs.isEmpty() && String.isNotBlank(contentWithImageRefs)
        ) {
          ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
          textSegment.text = stripHtmlTags(contentWithImageRefs);
          segmentInputs.add(textSegment);
        }
      }
      if (segmentInputs == null || segmentInputs.isEmpty()) {
        throw new AuraHandledException('Post body cannot be empty');
      }
      messageBodyInput.messageSegments = segmentInputs;

      ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
      feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
      feedItemInput.subjectId = req.subjectId;
      feedItemInput.body = messageBodyInput;

      // Attachments (pre-attach: existing ContentDocument via capabilities.files)
      if (hasFiles) {
        ConnectApi.FeedElementCapabilitiesInput caps = new ConnectApi.FeedElementCapabilitiesInput();
        caps.files = new ConnectApi.FilesCapabilityInput();
        caps.files.items = new List<ConnectApi.FileIdInput>();
        for (Id cdId : req.contentDocumentIds) {
          if (cdId != null) {
            ConnectApi.FileIdInput fileInput = new ConnectApi.FileIdInput();
            fileInput.id = cdId;
            caps.files.items.add(fileInput);
          }
        }
        if (!caps.files.items.isEmpty()) {
          feedItemInput.capabilities = caps;
        }
      }

      if (Test.isRunningTest()) {
        PostResult res = new PostResult();
        res.feedElementId = 'TEST_FEED_ITEM_ID';
        return res;
      }

      ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(
        networkId,
        feedItemInput
      );
      PostResult res = new PostResult();
      res.feedElementId = feedElement.id;

      // Topic assignment (if supported and topics provided)
      if (req.topics != null && !req.topics.isEmpty()) {
        assignTopicsToFeedElement(networkId, feedElement.id, req.topics);
      }
      return res;
    } catch (AuraHandledException e) {
      throw e;
    } catch (ConnectApi.ConnectApiException e) {
      throw new AuraHandledException(e.getMessage());
    } catch (Exception e) {
      System.debug('Error in postFeedElement: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException('Error posting: ' + e.getMessage());
    }
  }

  /**
   * Build ConnectApi message segments from DTOs (text, mention, link).
   */
  private static List<ConnectApi.MessageSegmentInput> buildSegmentsFromDtos(
    List<MessageSegmentDto> dtos
  ) {
    List<ConnectApi.MessageSegmentInput> segments = new List<ConnectApi.MessageSegmentInput>();
    if (dtos == null) {
      return segments;
    }
    for (MessageSegmentDto dto : dtos) {
      if (dto == null || dto.type == null) {
        continue;
      }
      if (dto.type == 'text' && String.isNotBlank(dto.text)) {
        ConnectApi.TextSegmentInput t = new ConnectApi.TextSegmentInput();
        t.text = dto.text;
        segments.add(t);
      } else if (dto.type == 'mention' && dto.refId != null) {
        ConnectApi.MentionSegmentInput m = new ConnectApi.MentionSegmentInput();
        m.id = dto.refId;
        segments.add(m);
      } else if (dto.type == 'link' && String.isNotBlank(dto.url)) {
        ConnectApi.LinkSegmentInput linkInput = new ConnectApi.LinkSegmentInput();
        linkInput.url = dto.url;
        segments.add(linkInput);
      }
    }
    return segments;
  }

  /**
   * Assign topics to a feed element by name (if ConnectApi supports it).
   * No-op if topic assignment is not available or fails.
   */
  @TestVisible
  private static void assignTopicsToFeedElement(
    Id networkId,
    String feedElementId,
    List<String> topicNames
  ) {
    if (topicNames == null || topicNames.isEmpty()) {
      return;
    }
    try {
      List<Topic> topics = [
        SELECT Id, Name
        FROM Topic
        WHERE Name IN :topicNames
        WITH SECURITY_ENFORCED
        LIMIT 100
      ];
      if (topics.isEmpty()) {
        return;
      }
      List<Id> topicIds = new List<Id>();
      for (Topic t : topics) {
        topicIds.add(t.Id);
      }
      ConnectApi.ChatterFeeds.setFeedElementTopics(
        networkId,
        feedElementId,
        topicIds
      );
    } catch (Exception e) {
      System.debug('Topic assignment skipped or failed: ' + e.getMessage());
    }
  }

  /**
   * Creates a Question (Chatter Answers) and returns its id and associated feed element if any.
   */
  @AuraEnabled
  public static PostResult createQuestion(QuestionRequest req) {
    if (req == null || req.subjectId == null) {
      throw new AuraHandledException('Subject ID is required');
    }
    if (String.isBlank(req.title)) {
      throw new AuraHandledException('Question title is required');
    }
    try {
      Id networkId = getNetworkId();
      QuestionDto q = new QuestionDto();
      q.title = req.title;
      q.detail = req.detail;
      q.topicNames = req.topicNames;
      return createQuestionFromRequest(q, req.subjectId, networkId);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      System.debug('Error in createQuestion: ' + e.getMessage());
      throw new AuraHandledException(
        'Error creating question: ' + e.getMessage()
      );
    }
  }

  private static PostResult createQuestionFromRequest(
    QuestionDto q,
    Id subjectId,
    Id networkId
  ) {
    PostResult res = new PostResult();
    try {
      if (Test.isRunningTest()) {
        res.questionId = 'TEST_QUESTION_ID';
        res.feedElementId = 'TEST_QUESTION_FEED_ID';
        return res;
      }
      ConnectApi.QuestionInput questionInput = new ConnectApi.QuestionInput();
      questionInput.title = q.title;
      questionInput.body = String.isNotBlank(q.detail) ? q.detail : '';
      ConnectApi.Question question = ConnectApi.Questions.createQuestion(
        networkId,
        questionInput,
        subjectId
      );
      res.questionId = question.id;
      if (question.feedElementId != null) {
        res.feedElementId = question.feedElementId;
      }
      if (
        q.topicNames != null &&
        !q.topicNames.isEmpty() &&
        String.isNotBlank(res.feedElementId)
      ) {
        assignTopicsToFeedElement(networkId, res.feedElementId, q.topicNames);
      }
      return res;
    } catch (ConnectApi.ConnectApiException e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Search for users and groups for @mention typeahead.
   * @param prefix Search prefix (e.g. after typing @)
   * @param limitMax Max results (default 20)
   * @return List of MentionOption with id, label, type (User | Group)
   */
  @AuraEnabled(cacheable=true)
  public static List<MentionOption> searchMentionable(
    String prefix,
    Integer limitMax
  ) {
    Integer limitVal = (limitMax != null &&
      limitMax > 0)
      ? Math.min(limitMax, 50)
      : 20;
    List<MentionOption> results = new List<MentionOption>();
    if (String.isBlank(prefix) || prefix.length() < 2) {
      return results;
    }
    String searchPattern = String.escapeSingleQuotes(prefix.trim()) + '%';
    try {
      List<User> users = [
        SELECT Id, Name
        FROM User
        WHERE IsActive = TRUE AND Name LIKE :searchPattern
        WITH SECURITY_ENFORCED
        LIMIT :limitVal
      ];
      for (User u : users) {
        MentionOption opt = new MentionOption();
        opt.id = u.Id;
        opt.label = u.Name;
        opt.type = 'User';
        results.add(opt);
      }
      Integer remaining = limitVal - results.size();
      if (remaining > 0) {
        List<CollaborationGroup> groups = [
          SELECT Id, Name
          FROM CollaborationGroup
          WHERE Name LIKE :searchPattern
          WITH SECURITY_ENFORCED
          LIMIT :remaining
        ];
        for (CollaborationGroup g : groups) {
          MentionOption opt = new MentionOption();
          opt.id = g.Id;
          opt.label = g.Name;
          opt.type = 'Group';
          results.add(opt);
        }
      }
    } catch (Exception e) {
      System.debug('searchMentionable error: ' + e.getMessage());
    }
    return results;
  }

  /**
   * Adds a comment to a feed element.
   */
  @AuraEnabled
  public static String addComment(CommentRequest req) {
    if (req == null || req.feedElementId == null) {
      throw new AuraHandledException('Feed element ID and body are required');
    }
    List<ConnectApi.MessageSegmentInput> segmentInputs;
    if (req.segments != null && !req.segments.isEmpty()) {
      segmentInputs = buildSegmentsFromDtos(req.segments);
    } else if (String.isNotBlank(req.body)) {
      ConnectApi.TextSegmentInput t = new ConnectApi.TextSegmentInput();
      t.text = req.body;
      segmentInputs = new List<ConnectApi.MessageSegmentInput>{ t };
    } else {
      throw new AuraHandledException('Comment body is required');
    }
    try {
      Id networkId = getNetworkId();
      if (Test.isRunningTest()) {
        return 'TEST_COMMENT_ID';
      }
      ConnectApi.MessageBodyInput bodyInput = new ConnectApi.MessageBodyInput();
      bodyInput.messageSegments = segmentInputs;
      ConnectApi.Comment comment = ConnectApi.Comments.createComment(
        networkId,
        req.feedElementId,
        bodyInput
      );
      return comment.id;
    } catch (AuraHandledException e) {
      throw e;
    } catch (ConnectApi.ConnectApiException e) {
      throw new AuraHandledException(e.getMessage());
    } catch (Exception e) {
      System.debug('Error in addComment: ' + e.getMessage());
      throw new AuraHandledException('Error adding comment: ' + e.getMessage());
    }
  }

  /**
   * Gets the network ID for the current community context
   * Falls back to querying for the Spokane Mountaineers network if not in community context
   * @return The network ID, or null if not found
   */
  private static Id getNetworkId() {
    Id networkId = Network.getNetworkId();

    // If we're not in a community context, try to find the Spokane Mountaineers network
    if (networkId == null) {
      List<Network> networks = [
        SELECT Id
        FROM Network
        WHERE Name = 'Spokane Mountaineers' AND Status = 'Live'
        LIMIT 1
      ];

      if (!networks.isEmpty()) {
        networkId = networks[0].Id;
      }
    }

    return networkId;
  }

  /**
   * Finds <img src="data:image/...;base64,..."> in content, creates ContentVersion for each,
   * and replaces the tag with {img:contentDocumentId} for use in message segments.
   * @param content HTML that may contain data-URI images
   * @return Content with data-URI img tags replaced by {img:contentDocumentId}
   */
  @TestVisible
  private static String replaceDataUriImagesWithPlaceholders(String content) {
    if (String.isBlank(content)) {
      return content;
    }
    Pattern p = Pattern.compile('<img[^>]*src="data:image/[^"]*"[^>]*>');
    Matcher m = p.matcher(content);
    String result = content;
    while (m.find()) {
      String fullTag = m.group(0);
      Integer base64Start = fullTag.indexOf(';base64,');
      if (base64Start < 0) {
        continue;
      }
      base64Start += 8;
      Integer base64End = fullTag.indexOf('"', base64Start);
      if (base64End < 0) {
        continue;
      }
      String base64Data = fullTag.substring(base64Start, base64End);
      String contentType = 'png';
      Integer typeStart = fullTag.indexOf('data:image/');
      if (typeStart >= 0) {
        typeStart += 11;
        Integer typeEnd = fullTag.indexOf(';', typeStart);
        if (typeEnd > typeStart) {
          contentType = fullTag.substring(typeStart, typeEnd);
        }
      }
      String contentDocumentId = createContentVersionFromBase64(
        base64Data,
        contentType
      );
      if (String.isNotBlank(contentDocumentId)) {
        result =
          result.substring(0, m.start()) +
          '{img:' +
          contentDocumentId +
          '}' +
          result.substring(m.end());
        m = p.matcher(result);
      }
    }
    return result;
  }

  /**
   * Creates a ContentVersion from base64-encoded image data and returns the ContentDocumentId.
   * Used for inline images in Chatter posts.
   */
  private static String createContentVersionFromBase64(
    String base64Data,
    String contentType
  ) {
    if (String.isBlank(base64Data)) {
      return null;
    }
    try {
      Blob versionData = EncodingUtil.base64Decode(base64Data);
      String ext = 'png';
      if (contentType != null) {
        String ct = contentType.toLowerCase();
        if (ct == 'jpeg' || ct == 'jpg') {
          ext = 'jpg';
        } else if (ct == 'gif') {
          ext = 'gif';
        } else if (ct == 'webp') {
          ext = 'webp';
        }
      }
      ContentVersion cv = new ContentVersion();
      cv.Title = 'Chatter Image';
      cv.PathOnClient = 'image.' + ext;
      cv.VersionData = versionData;
      insert cv;
      cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id][0];
      return (String) cv.ContentDocumentId;
    } catch (Exception e) {
      System.debug(
        'Error creating ContentVersion from base64: ' + e.getMessage()
      );
      return null;
    }
  }

  /**
   * Builds message segments from content that may contain {img:contentDocumentId} placeholders.
   * Interleaves HTML segment output with InlineImageSegmentInput for each placeholder.
   */
  private static List<ConnectApi.MessageSegmentInput> buildMessageSegmentsWithImages(
    String content
  ) {
    List<ConnectApi.MessageSegmentInput> segments = new List<ConnectApi.MessageSegmentInput>();
    if (String.isBlank(content)) {
      return segments;
    }
    // Pattern: {img:15-or-18-char-id} or {img:id:alt text}
    Pattern imgPattern = Pattern.compile(
      '\\{img:(069[a-zA-Z0-9]{12,15})(?::([^}]*))?\\}'
    );
    Matcher m = imgPattern.matcher(content);
    Integer lastEnd = 0;
    while (m.find()) {
      String htmlPart = content.substring(lastEnd, m.start());
      if (String.isNotBlank(htmlPart)) {
        segments.addAll(htmlToMessageSegmentInputs(htmlPart));
      }
      ConnectApi.InlineImageSegmentInput imgSeg = new ConnectApi.InlineImageSegmentInput();
      imgSeg.fileId = m.group(1);
      if (m.groupCount() >= 2 && String.isNotBlank(m.group(2))) {
        imgSeg.altText = m.group(2).trim();
      }
      segments.add(imgSeg);
      lastEnd = m.end();
    }
    if (lastEnd < content.length()) {
      String trailing = content.substring(lastEnd);
      if (String.isNotBlank(trailing)) {
        segments.addAll(htmlToMessageSegmentInputs(trailing));
      }
    }
    return segments;
  }

  /**
   * Converts rich text HTML (e.g. from lightning-input-rich-text) into ConnectApi message segments
   * so that bold, italic, underline, and links are preserved when posting to Chatter.
   * Requires "Rich Text Posts" enabled in Chatter settings.
   * @param html The HTML content
   * @return List of message segment inputs, or empty list if input is blank
   */
  @TestVisible
  private static List<ConnectApi.MessageSegmentInput> htmlToMessageSegmentInputs(
    String html
  ) {
    List<ConnectApi.MessageSegmentInput> segments = new List<ConnectApi.MessageSegmentInput>();
    if (String.isBlank(html)) {
      return segments;
    }
    String normalized = html
      .replaceAll('<br\\s*/?>', '\n')
      .replaceAll('</p>', '\n')
      .replaceAll('<p>', '')
      .replaceAll('<p\\s[^>]*>', '')
      .replaceAll('<li[^>]*>', '\n• ')
      .replaceAll('</li>', '')
      .replaceAll('</?ul>', '\n')
      .replaceAll('</?ol>', '\n');
    List<String> blocks = normalized.split('\n');
    for (String block : blocks) {
      block = block.trim();
      if (block.length() == 0) {
        continue;
      }
      addParagraphWithInlineMarkup(segments, block);
    }
    return segments;
  }

  /**
   * Appends a paragraph (Paragraph begin/end) and parses inline markup (bold, italic, underline, links) inside it.
   */
  private static void addParagraphWithInlineMarkup(
    List<ConnectApi.MessageSegmentInput> segments,
    String block
  ) {
    ConnectApi.MarkupBeginSegmentInput pBegin = new ConnectApi.MarkupBeginSegmentInput();
    pBegin.markupType = ConnectApi.MarkupType.Paragraph;
    segments.add(pBegin);

    parseInlineMarkup(segments, block);

    ConnectApi.MarkupEndSegmentInput pEnd = new ConnectApi.MarkupEndSegmentInput();
    pEnd.markupType = ConnectApi.MarkupType.Paragraph;
    segments.add(pEnd);
  }

  /**
   * Parses inline HTML (bold, italic, underline, hyperlinks) and appends corresponding segments.
   * Handles <b>, <strong>, <i>, <em>, <u>, <a href="...">...</a>. Decodes HTML entities in text.
   */
  private static void parseInlineMarkup(
    List<ConnectApi.MessageSegmentInput> segments,
    String html
  ) {
    Integer pos = 0;
    Integer len = html.length();
    while (pos < len) {
      Integer nextOpen = html.indexOf('<', pos);
      if (nextOpen < 0) {
        String text = decodeHtmlEntities(html.substring(pos)).trim();
        if (text.length() > 0) {
          ConnectApi.TextSegmentInput t = new ConnectApi.TextSegmentInput();
          t.text = text;
          segments.add(t);
        }
        break;
      }
      if (nextOpen > pos) {
        String text = decodeHtmlEntities(html.substring(pos, nextOpen)).trim();
        if (text.length() > 0) {
          ConnectApi.TextSegmentInput t = new ConnectApi.TextSegmentInput();
          t.text = text;
          segments.add(t);
        }
      }
      Integer closeBracket = html.indexOf('>', nextOpen);
      if (closeBracket < 0) {
        pos = nextOpen + 1;
        continue;
      }
      String tag = html.substring(nextOpen + 1, closeBracket)
        .trim()
        .toLowerCase();
      if (tag.indexOf(' ') > 0) {
        tag = tag.substring(0, tag.indexOf(' '));
      }
      Integer endTag = html.indexOf('</' + tag + '>', closeBracket + 1);
      if (endTag < 0) {
        endTag = html.indexOf('</' + tag + ' ', closeBracket + 1);
      }
      if (tag == 'a') {
        String href = extractHref(html.substring(nextOpen, closeBracket + 1));
        String linkBody = endTag > closeBracket
          ? html.substring(closeBracket + 1, endTag)
          : '';
        linkBody = decodeHtmlEntities(linkBody).trim();
        if (String.isNotBlank(href)) {
          ConnectApi.MarkupBeginSegmentInput linkBegin = new ConnectApi.MarkupBeginSegmentInput();
          linkBegin.markupType = ConnectApi.MarkupType.Hyperlink;
          linkBegin.url = href;
          segments.add(linkBegin);
          if (String.isNotBlank(linkBody)) {
            ConnectApi.TextSegmentInput linkText = new ConnectApi.TextSegmentInput();
            linkText.text = linkBody;
            segments.add(linkText);
          }
          ConnectApi.MarkupEndSegmentInput linkEnd = new ConnectApi.MarkupEndSegmentInput();
          linkEnd.markupType = ConnectApi.MarkupType.Hyperlink;
          segments.add(linkEnd);
        } else if (String.isNotBlank(linkBody)) {
          ConnectApi.TextSegmentInput linkText = new ConnectApi.TextSegmentInput();
          linkText.text = linkBody;
          segments.add(linkText);
        }
        pos = endTag > closeBracket
          ? endTag + 4 + tag.length()
          : closeBracket + 1;
        continue;
      }
      if (tag == 'b' || tag == 'strong') {
        ConnectApi.MarkupBeginSegmentInput b = new ConnectApi.MarkupBeginSegmentInput();
        b.markupType = ConnectApi.MarkupType.Bold;
        segments.add(b);
        if (endTag > closeBracket) {
          parseInlineMarkup(segments, html.substring(closeBracket + 1, endTag));
        }
        ConnectApi.MarkupEndSegmentInput bEnd = new ConnectApi.MarkupEndSegmentInput();
        bEnd.markupType = ConnectApi.MarkupType.Bold;
        segments.add(bEnd);
        pos = endTag > closeBracket
          ? endTag + 4 + tag.length()
          : closeBracket + 1;
        continue;
      }
      if (tag == 'i' || tag == 'em') {
        ConnectApi.MarkupBeginSegmentInput i = new ConnectApi.MarkupBeginSegmentInput();
        i.markupType = ConnectApi.MarkupType.Italic;
        segments.add(i);
        if (endTag > closeBracket) {
          parseInlineMarkup(segments, html.substring(closeBracket + 1, endTag));
        }
        ConnectApi.MarkupEndSegmentInput iEnd = new ConnectApi.MarkupEndSegmentInput();
        iEnd.markupType = ConnectApi.MarkupType.Italic;
        segments.add(iEnd);
        pos = endTag > closeBracket
          ? endTag + 4 + tag.length()
          : closeBracket + 1;
        continue;
      }
      if (tag == 'u') {
        ConnectApi.MarkupBeginSegmentInput u = new ConnectApi.MarkupBeginSegmentInput();
        u.markupType = ConnectApi.MarkupType.Underline;
        segments.add(u);
        if (endTag > closeBracket) {
          parseInlineMarkup(segments, html.substring(closeBracket + 1, endTag));
        }
        ConnectApi.MarkupEndSegmentInput uEnd = new ConnectApi.MarkupEndSegmentInput();
        uEnd.markupType = ConnectApi.MarkupType.Underline;
        segments.add(uEnd);
        pos = endTag > closeBracket
          ? endTag + 4 + tag.length()
          : closeBracket + 1;
        continue;
      }
      if (tag == 's' || tag == 'strike') {
        ConnectApi.MarkupBeginSegmentInput s = new ConnectApi.MarkupBeginSegmentInput();
        s.markupType = ConnectApi.MarkupType.Strikethrough;
        segments.add(s);
        if (endTag > closeBracket) {
          parseInlineMarkup(segments, html.substring(closeBracket + 1, endTag));
        }
        ConnectApi.MarkupEndSegmentInput sEnd = new ConnectApi.MarkupEndSegmentInput();
        sEnd.markupType = ConnectApi.MarkupType.Strikethrough;
        segments.add(sEnd);
        pos = endTag > closeBracket
          ? endTag + 4 + tag.length()
          : closeBracket + 1;
        continue;
      }
      pos = closeBracket + 1;
    }
  }

  private static String extractHref(String tagBlock) {
    Integer hrefStart = tagBlock.toLowerCase().indexOf('href="');
    if (hrefStart < 0) {
      return '';
    }
    Integer start = hrefStart + 6;
    Integer quoteEnd = tagBlock.indexOf('"', start);
    if (quoteEnd < 0) {
      return '';
    }
    return tagBlock.substring(start, quoteEnd)
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"');
  }

  private static String decodeHtmlEntities(String s) {
    if (String.isBlank(s)) {
      return '';
    }
    String r = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', '\'');
    return r;
  }

  /**
   * Strips HTML tags from content for plain text posting
   * Preserves line breaks by converting <br> and </p> tags to newlines
   * @param html The HTML content to strip
   * @return Plain text content with preserved line breaks
   */
  private static String stripHtmlTags(String html) {
    if (String.isBlank(html)) {
      return '';
    }

    // Convert common HTML line breaks to actual line breaks
    String result = html;
    result = result.replaceAll('<br\\s*/?>', '\n');
    result = result.replaceAll('</p>', '\n');
    result = result.replaceAll('<p>', '');

    // Convert list items to bullet points
    result = result.replaceAll('<li>', '• ');
    result = result.replaceAll('</li>', '\n');
    result = result.replaceAll('</?ul>', '\n');
    result = result.replaceAll('</?ol>', '\n');

    // Remove all other HTML tags
    result = result.replaceAll('<[^>]+>', '');

    // Decode common HTML entities
    result = result.replaceAll('&nbsp;', ' ');
    result = result.replaceAll('&amp;', '&');
    result = result.replaceAll('&lt;', '<');
    result = result.replaceAll('&gt;', '>');
    result = result.replaceAll('&quot;', '"');
    result = result.replaceAll('&#39;', '\'');

    // Clean up multiple consecutive newlines
    result = result.replaceAll('\n\n\n+', '\n\n');

    return result.trim();
  }
}
