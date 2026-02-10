import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import postFeedElement from "@salesforce/apex/ChatterPublisherController.postFeedElement";
import postPollToChatter from "@salesforce/apex/ChatterPublisherController.postPollToChatter";
import searchMentionable from "@salesforce/apex/ChatterPublisherController.searchMentionable";
import createQuestion from "@salesforce/apex/ChatterPublisherController.createQuestion";

// Constants
const DRAFT_KEY_PREFIX = "chatterDraft_";
const POLL_DRAFT_KEY_PREFIX = "chatterPollDraft_";
const AUTOSAVE_DELAY_MS = 3000;
const DRAFT_SAVED_MESSAGE_DURATION_MS = 3000;
const DRAFT_EXPIRATION_DAYS = 7;
const MS_PER_DAY = 1000 * 60 * 60 * 24;

export default class ChatterPublisherWithAutosave extends LightningElement {
  @api groupId; // Collaboration Group ID

  draftContent = "";
  lastSavedText = "";
  isSaving = false;
  isPosting = false;
  showRestoreDraftModal = false;
  savedDraft = null;
  draftTimestamp = "";
  hasDraft = false;
  isExpanded = false;
  activeTab = "post";
  pollQuestion = "";
  questionTitle = "";
  questionDetail = "";
  questionTopicChips = [];
  pollChoices = [
    { id: "1", value: "", canRemove: false },
    { id: "2", value: "", canRemove: false }
  ];
  _pollChoiceId = 3;
  MAX_POLL_CHOICES = 10;

  // Segment model for @mentions, links (parallel to rich text)
  postSegments = [];
  // Topic chips for #topics
  topicChips = [];
  // Mention typeahead
  showMentionDropdown = false;
  mentionSearchTerm = "";
  mentionOptions = [];
  mentionLoading = false;
  mentionDebounceTimeout = null;
  MENTION_DEBOUNCE_MS = 250;
  MENTION_MIN_LENGTH = 2;

  // Post-attach file upload: after post, show upload with record-id = feed element
  lastCreatedFeedElementId = null;
  showFileUploadAfterPost = false;

  // Emoji picker
  showEmojiPicker = false;
  EMOJI_LIST = [
    "😀",
    "😊",
    "😂",
    "❤️",
    "👍",
    "🎉",
    "🔥",
    "✨",
    "🙏",
    "💪",
    "😍",
    "🥳",
    "✅",
    "⭐",
    "💯",
    "🙌"
  ];

  saveTimeout = null;
  pollSaveTimeout = null;
  savedMessageTimeout = null;
  savedPollMessageTimeout = null;
  hasUnsavedChanges = false;
  _internalGroupId = null;
  lastPollSavedText = "";
  isSavingPoll = false;

  // Rich text editor formats
  formats = [
    "font",
    "size",
    "bold",
    "italic",
    "underline",
    "strike",
    "list",
    "indent",
    "align",
    "link",
    "clean"
  ];

  // Get group ID from page reference if not provided via @api
  @wire(CurrentPageReference)
  getPageReference(pageRef) {
    if (
      pageRef &&
      pageRef.attributes &&
      pageRef.attributes.recordId &&
      !this.groupId
    ) {
      this._internalGroupId = pageRef.attributes.recordId;
      this.loadDraftFromLocalStorage();
    }
  }

  get effectiveGroupId() {
    return this.groupId || this._internalGroupId;
  }

  get isPostTab() {
    return this.activeTab === "post";
  }

  get isPollTab() {
    return this.activeTab === "poll";
  }

  get isQuestionTab() {
    return this.activeTab === "question";
  }

  get isPostTabActive() {
    return this.activeTab === "post";
  }

  get isPollTabActive() {
    return this.activeTab === "poll";
  }

  get isQuestionTabActive() {
    return this.activeTab === "question";
  }

  get canAddPollChoice() {
    return this.pollChoices.length < this.MAX_POLL_CHOICES;
  }

  get validPollChoicesCount() {
    return this.pollChoices.filter((c) => c.value && c.value.trim()).length;
  }

  get isPollShareDisabled() {
    return (
      this.isPosting ||
      !this.pollQuestion ||
      this.pollQuestion.trim().length === 0 ||
      this.validPollChoicesCount < 2
    );
  }

  get isQuestionShareDisabled() {
    return (
      this.isPosting ||
      !this.questionTitle ||
      this.questionTitle.trim().length === 0
    );
  }

  get restoreDraftModalTitle() {
    return this.savedDraft?.type === "poll"
      ? "Restore Poll Draft?"
      : "Restore Draft?";
  }

  get restoreDraftModalLabel() {
    return this.savedDraft?.type === "poll" ? "poll draft" : "draft";
  }

  connectedCallback() {
    // If groupId is already set (via @api), load post draft immediately
    if (this.effectiveGroupId) {
      this.loadDraftFromLocalStorage();
    }

    // Add beforeunload listener to warn about unsaved changes
    this.handleBeforeUnload = this.beforeUnloadHandler.bind(this);
    window.addEventListener("beforeunload", this.handleBeforeUnload);

    // Clean up expired drafts on load
    this.cleanupExpiredDrafts();
  }

  disconnectedCallback() {
    // Remove beforeunload listener
    window.removeEventListener("beforeunload", this.handleBeforeUnload);

    // Clear any pending save timeouts
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
    }
    if (this.pollSaveTimeout) {
      clearTimeout(this.pollSaveTimeout);
    }
  }

  beforeUnloadHandler(event) {
    const hasPostDraft =
      this.hasUnsavedChanges && this.isContentNotEmpty(this.draftContent);
    const hasPollDraft =
      this.activeTab === "poll" &&
      this.isExpanded &&
      (this.pollQuestion?.trim() ||
        this.pollChoices.some((c) => c.value && c.value.trim()));
    if (hasPostDraft || hasPollDraft) {
      event.preventDefault();
      event.returnValue =
        "You have unsaved changes. Are you sure you want to leave?";
      return event.returnValue;
    }
    return undefined;
  }

  handleExpandPublisher() {
    this.isExpanded = true;
  }

  handleCollapsePublisher() {
    if (
      this.activeTab === "post" &&
      !this.isContentNotEmpty(this.draftContent)
    ) {
      this.isExpanded = false;
    }
    if (this.activeTab === "poll") {
      this.isExpanded = false;
      this.pollQuestion = "";
      this.pollChoices = [
        { id: "1", value: "", canRemove: false },
        { id: "2", value: "", canRemove: false }
      ];
      this._pollChoiceId = 3;
      this.clearPollDraftFromLocalStorage();
    }
    if (this.activeTab === "question") {
      this.isExpanded = false;
      this.questionTitle = "";
      this.questionDetail = "";
      this.questionTopicChips = [];
    }
  }

  handleTabClick(event) {
    const tab = event.currentTarget.dataset.tab;
    if (tab === this.activeTab) return;
    this.activeTab = tab;
    if (tab === "poll") {
      this.loadPollDraftFromLocalStorage();
    }
  }

  handlePollQuestionChange(event) {
    this.pollQuestion = event.target.value;
    this.schedulePollDraftSave();
  }

  handlePollChoiceChange(event) {
    const id = event.target.dataset.choiceId;
    const value = event.target.value;
    this.pollChoices = this.pollChoices.map((c) => {
      return c.id === id ? { ...c, value } : c;
    });
    this.schedulePollDraftSave();
  }

  schedulePollDraftSave() {
    if (this.pollSaveTimeout) {
      clearTimeout(this.pollSaveTimeout);
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.pollSaveTimeout = setTimeout(() => {
      this.savePollDraftToLocalStorage();
    }, AUTOSAVE_DELAY_MS);
  }

  savePollDraftToLocalStorage() {
    if (!this.effectiveGroupId) return;
    const hasQuestion = this.pollQuestion && this.pollQuestion.trim();
    const validChoices = this.pollChoices
      .map((c) => c.value && c.value.trim())
      .filter(Boolean);
    if (!hasQuestion && validChoices.length === 0) return;

    this.isSavingPoll = true;
    try {
      const key = this.getPollDraftKey();
      const draft = {
        type: "poll",
        question: this.pollQuestion || "",
        choices: this.pollChoices.map((c) => c.value || ""),
        timestamp: new Date().toISOString(),
        groupId: this.effectiveGroupId
      };
      localStorage.setItem(key, JSON.stringify(draft));
      this.lastPollSavedText =
        "Draft saved " + this.getRelativeTime(draft.timestamp);

      if (this.savedPollMessageTimeout) {
        clearTimeout(this.savedPollMessageTimeout);
      }
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this.savedPollMessageTimeout = setTimeout(() => {
        this.lastPollSavedText = "";
        this.savedPollMessageTimeout = null;
      }, DRAFT_SAVED_MESSAGE_DURATION_MS);
    } catch (error) {
      console.error("Error saving poll draft:", error);
    } finally {
      this.isSavingPoll = false;
    }
  }

  loadPollDraftFromLocalStorage() {
    if (!this.effectiveGroupId) return;
    try {
      const key = this.getPollDraftKey();
      const draftJson = localStorage.getItem(key);
      if (!draftJson) return;
      const draft = JSON.parse(draftJson);
      if (this.isDraftExpired(draft.timestamp)) {
        this.clearPollDraftFromLocalStorage();
        return;
      }
      this.savedDraft = draft;
      this.draftTimestamp = this.getRelativeTime(draft.timestamp);
      this.showRestoreDraftModal = true;
    } catch (error) {
      console.error("Error loading poll draft:", error);
    }
  }

  clearPollDraftFromLocalStorage() {
    try {
      localStorage.removeItem(this.getPollDraftKey());
    } catch (error) {
      console.error("Error clearing poll draft:", error);
    }
  }

  getPollDraftKey() {
    return POLL_DRAFT_KEY_PREFIX + this.effectiveGroupId;
  }

  handleAddPollChoice() {
    if (this.pollChoices.length >= this.MAX_POLL_CHOICES) return;
    const id = String(this._pollChoiceId++);
    this.pollChoices = [
      ...this.pollChoices.map((c) => ({
        ...c,
        canRemove: true
      })),
      { id, value: "", canRemove: true }
    ];
  }

  handleRemovePollChoice(event) {
    const id = event.target.dataset.choiceId;
    const next = this.pollChoices.filter((c) => c.id !== id);
    if (next.length < 2) return;
    this.pollChoices = next.map((c) => ({
      ...c,
      canRemove: next.length > 2
    }));
  }

  async handlePostPoll() {
    if (this.isPollShareDisabled || !this.effectiveGroupId) return;
    const choices = this.pollChoices
      .map((c) => c.value && c.value.trim())
      .filter(Boolean);
    if (choices.length < 2) {
      this.showToast("Error", "At least 2 choices are required", "error");
      return;
    }
    this.isPosting = true;
    try {
      await postPollToChatter({
        groupId: this.effectiveGroupId,
        question: this.pollQuestion.trim(),
        choices
      });
      this.showToast("Success", "Your poll has been shared", "success");
      this.isExpanded = false;
      this.pollQuestion = "";
      this.pollChoices = [
        { id: "1", value: "", canRemove: false },
        { id: "2", value: "", canRemove: false }
      ];
      this._pollChoiceId = 3;
      this.clearPollDraftFromLocalStorage();
      this.dispatchEvent(new CustomEvent("postpublished"));
      window.location.reload();
    } catch (error) {
      const errorMessage =
        error.body?.message ||
        error.message ||
        "An error occurred while posting the poll";
      this.showToast("Error", errorMessage, "error");
    } finally {
      this.isPosting = false;
    }
  }

  handleTextChange(event) {
    this.draftContent = event.target.value;
    this.hasUnsavedChanges = true;
    this.hasDraft = this.isContentNotEmpty(this.draftContent);

    // Detect @ for mention typeahead (plain text after last @)
    const plainText = this.getPlainTextFromHtml(this.draftContent);
    const atIndex = plainText.lastIndexOf("@");
    if (atIndex >= 0) {
      const afterAt = plainText.substring(atIndex + 1);
      const spaceIndex = afterAt.search(/\s/);
      const word = spaceIndex >= 0 ? afterAt.substring(0, spaceIndex) : afterAt;
      if (word.length >= this.MENTION_MIN_LENGTH) {
        this.mentionSearchTerm = word;
        this.scheduleMentionSearch();
      } else if (word.length === 0) {
        this.showMentionDropdown = false;
      }
    } else {
      this.showMentionDropdown = false;
    }

    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.saveTimeout = setTimeout(() => {
      this.saveDraftToLocalStorage();
    }, AUTOSAVE_DELAY_MS);
  }

  getPlainTextFromHtml(html) {
    if (!html) return "";
    const div = document.createElement("div");
    // eslint-disable-next-line @lwc/lwc/no-inner-html
    div.innerHTML = html;
    return (div.textContent || div.innerText || "").trim();
  }

  scheduleMentionSearch() {
    if (this.mentionDebounceTimeout) {
      clearTimeout(this.mentionDebounceTimeout);
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.mentionDebounceTimeout = setTimeout(() => {
      this.runMentionSearch();
    }, this.MENTION_DEBOUNCE_MS);
  }

  async runMentionSearch() {
    if (
      !this.mentionSearchTerm ||
      this.mentionSearchTerm.length < this.MENTION_MIN_LENGTH
    ) {
      this.showMentionDropdown = false;
      return;
    }
    this.mentionLoading = true;
    this.showMentionDropdown = true;
    try {
      const results = await searchMentionable({
        prefix: this.mentionSearchTerm,
        limitMax: 20
      });
      this.mentionOptions = Array.isArray(results) ? results : [];
    } catch (e) {
      console.error("Mention search failed:", e);
      this.mentionOptions = [];
    } finally {
      this.mentionLoading = false;
    }
  }

  handleMentionSelect(event) {
    const id = event.currentTarget.dataset.id;
    if (!id) return;
    // Insert placeholder at end of content (editor doesn't expose cursor)
    const placeholder = ` {mention:${id}} `;
    this.draftContent = (this.draftContent || "") + placeholder;
    this.showMentionDropdown = false;
    this.mentionOptions = [];
    this.mentionSearchTerm = "";
    this.hasDraft = true;
    this.hasUnsavedChanges = true;
  }

  handleCloseMentionDropdown() {
    this.showMentionDropdown = false;
  }

  // Topic chips
  topicInputValue = "";

  handleTopicInputChange(event) {
    this.topicInputValue = event.target.value || "";
  }

  handleAddTopic() {
    const name = (this.topicInputValue || "").trim();
    if (!name) return;
    if (!this.topicChips) this.topicChips = [];
    const exists = this.topicChips.some(
      (t) => (typeof t === "string" ? t : t.name || t.label) === name
    );
    if (exists) return;
    this.topicChips = [...this.topicChips, { name, label: name }];
    this.topicInputValue = "";
  }

  handleRemoveTopic(event) {
    const name = event.currentTarget.dataset.name;
    if (!name) return;
    this.topicChips = (this.topicChips || []).filter(
      (t) => (typeof t === "string" ? t : t.name || t.label) !== name
    );
  }

  handleTopicKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.handleAddTopic();
    }
  }

  get hasTopicChips() {
    return this.topicChips && this.topicChips.length > 0;
  }

  get topicChipsList() {
    if (!this.topicChips || !this.topicChips.length) return [];
    return this.topicChips.map((t) => {
      const name = typeof t === "string" ? t : t.name || t.label || "";
      return { key: name, name };
    });
  }

  handleFileUploadDone() {
    this.lastCreatedFeedElementId = null;
    this.showFileUploadAfterPost = false;
    window.location.reload();
  }

  handleToggleEmojiPicker() {
    this.showEmojiPicker = !this.showEmojiPicker;
  }

  handleEmojiSelect(event) {
    const emoji = event.currentTarget.dataset.emoji;
    if (emoji) {
      this.draftContent = (this.draftContent || "") + emoji;
      this.hasDraft = true;
      this.hasUnsavedChanges = true;
      this.showEmojiPicker = false;
    }
  }

  handleQuestionTitleChange(event) {
    this.questionTitle = event.target.value || "";
  }

  handleQuestionDetailChange(event) {
    this.questionDetail = event.target.value || "";
  }

  async handlePostQuestion() {
    if (this.isQuestionShareDisabled || !this.effectiveGroupId) return;
    this.isPosting = true;
    try {
      const topicNames =
        this.questionTopicChips && this.questionTopicChips.length > 0
          ? this.questionTopicChips.map((t) => {
              return typeof t === "string" ? t : t.name || t.label;
            })
          : null;
      const res = await createQuestion({
        subjectId: this.effectiveGroupId,
        title: this.questionTitle.trim(),
        detail: this.questionDetail ? this.questionDetail.trim() : null,
        topicNames
      });
      this.showToast("Success", "Your question has been posted", "success");
      this.questionTitle = "";
      this.questionDetail = "";
      this.questionTopicChips = [];
      this.isExpanded = false;
      this.dispatchEvent(
        new CustomEvent("postpublished", {
          detail: {
            feedElementId: res.feedElementId,
            questionId: res.questionId
          }
        })
      );
      window.location.reload();
    } catch (error) {
      const msg =
        error.body?.message ||
        error.message ||
        "An error occurred while posting the question";
      this.showToast("Error", msg, "error");
    } finally {
      this.isPosting = false;
    }
  }

  saveDraftToLocalStorage() {
    if (!this.effectiveGroupId || !this.isContentNotEmpty(this.draftContent)) {
      return;
    }

    this.isSaving = true;

    try {
      const draftKey = this.getDraftKey();
      const draft = {
        content: this.draftContent,
        timestamp: new Date().toISOString(),
        groupId: this.effectiveGroupId,
        topics:
          this.topicChips && this.topicChips.length > 0
            ? this.topicChips.map((t) =>
                typeof t === "string" ? t : t.name || t.label
              )
            : []
      };

      localStorage.setItem(draftKey, JSON.stringify(draft));

      this.lastSavedText =
        "Draft saved " + this.getRelativeTime(draft.timestamp);
      this.hasUnsavedChanges = false;

      if (this.savedMessageTimeout) {
        clearTimeout(this.savedMessageTimeout);
      }
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this.savedMessageTimeout = setTimeout(() => {
        this.lastSavedText = "";
        this.savedMessageTimeout = null;
      }, DRAFT_SAVED_MESSAGE_DURATION_MS);
    } catch (error) {
      console.error("Error saving draft to localStorage:", error);
      this.showToast("Error", "Unable to save draft locally", "error");
    } finally {
      this.isSaving = false;
    }
  }

  loadDraftFromLocalStorage() {
    if (!this.effectiveGroupId) return;
    try {
      const draftKey = this.getDraftKey();
      const draftJson = localStorage.getItem(draftKey);
      if (!draftJson) return;
      const draft = JSON.parse(draftJson);
      if (this.isDraftExpired(draft.timestamp)) {
        this.clearDraftFromLocalStorage();
        return;
      }
      this.savedDraft = { type: "post", ...draft };
      this.draftTimestamp = this.getRelativeTime(draft.timestamp);
      this.showRestoreDraftModal = true;
    } catch (error) {
      console.error("Error loading draft from localStorage:", error);
    }
  }

  handleRestoreDraft() {
    if (this.savedDraft) {
      if (this.savedDraft.type === "poll") {
        this.pollQuestion = this.savedDraft.question || "";
        const choices = this.savedDraft.choices || ["", ""];
        this.pollChoices = choices.map((val, i) => ({
          id: String(i + 1),
          value: val,
          canRemove: choices.length > 2
        }));
        this._pollChoiceId = choices.length + 1;
        this.activeTab = "poll";
        this.lastPollSavedText = "Draft restored from " + this.draftTimestamp;
      } else {
        this.draftContent = this.savedDraft.content || "";
        this.topicChips = Array.isArray(this.savedDraft.topics)
          ? this.savedDraft.topics.map((name) => ({ name, label: name }))
          : [];
        this.hasDraft = true;
        this.hasUnsavedChanges = false;
        this.lastSavedText = "Draft restored from " + this.draftTimestamp;
      }
      this.isExpanded = true;
    }
    this.showRestoreDraftModal = false;
  }

  handleDiscardDraft() {
    if (this.savedDraft && this.savedDraft.type === "poll") {
      this.clearPollDraftFromLocalStorage();
    } else {
      this.clearDraftFromLocalStorage();
    }
    this.showRestoreDraftModal = false;
  }

  handleClearDraft() {
    this.draftContent = "";
    this.hasDraft = false;
    this.hasUnsavedChanges = false;
    this.lastSavedText = "";
    this.clearDraftFromLocalStorage();
    this.isExpanded = false;
    this.showToast("Success", "Draft cleared", "success");
  }

  async handlePost() {
    const segments = this.buildSegmentsForSubmit();
    const hasSegments = segments && segments.length > 0;
    const hasContent = this.isContentNotEmpty(this.draftContent);
    if (!hasContent && !hasSegments) {
      this.showToast("Error", "Please enter some content to share", "error");
      return;
    }

    if (!this.effectiveGroupId) {
      this.showToast("Error", "Unable to determine group ID", "error");
      return;
    }

    this.isPosting = true;

    try {
      const req = {
        subjectId: this.effectiveGroupId,
        content: hasSegments ? null : hasContent ? this.draftContent : null,
        segments: segments || null,
        topics:
          this.topicChips && this.topicChips.length > 0
            ? this.topicChips.map((t) =>
                typeof t === "string" ? t : t.name || t.label
              )
            : null
      };
      const res = await postFeedElement(req);

      this.showToast("Success", "Your post has been shared", "success");

      // Clear draft and segments
      this.draftContent = "";
      this.postSegments = [];
      this.topicChips = [];
      this.hasDraft = false;
      this.hasUnsavedChanges = false;
      this.lastSavedText = "";
      this.clearDraftFromLocalStorage();

      this.lastCreatedFeedElementId = res.feedElementId;
      this.showFileUploadAfterPost = true;
      this.isExpanded = false;

      this.dispatchEvent(
        new CustomEvent("postpublished", {
          detail: { feedElementId: res.feedElementId }
        })
      );
    } catch (error) {
      console.error("Error posting to Chatter:", error);
      const errorMessage =
        error.body?.message ||
        error.message ||
        "An error occurred while posting";
      this.showToast("Error", errorMessage, "error");
    } finally {
      this.isPosting = false;
    }
  }

  /**
   * Build segment DTOs for Apex (text, mention, link).
   * If content contains {mention:id} placeholders, parse and return segments; else return null so Apex uses content (HTML) path.
   */
  buildSegmentsForSubmit() {
    if (this.postSegments && this.postSegments.length > 0) {
      return this.postSegments
        .map((seg) => {
          if (seg.type === "text") {
            return { type: "text", text: seg.value || seg.text || "" };
          }
          if (seg.type === "mention") {
            return { type: "mention", refId: seg.id || seg.refId };
          }
          if (seg.type === "link") {
            return { type: "link", url: seg.url || "" };
          }
          return null;
        })
        .filter(Boolean);
    }
    // Parse content for {mention:userId} placeholders
    const content = this.draftContent || "";
    if (!content.includes("{mention:")) {
      return null;
    }
    const mentionRegex = /\{mention:([^}]+)\}/g;
    const segments = [];
    let lastIndex = 0;
    let match;
    while ((match = mentionRegex.exec(content)) !== null) {
      const textPart = content.substring(lastIndex, match.index);
      const plainText = this.getPlainTextFromHtml(textPart);
      if (plainText.length > 0) {
        segments.push({ type: "text", text: plainText });
      }
      segments.push({ type: "mention", refId: match[1] });
      lastIndex = match.index + match[0].length;
    }
    const trailing = content.substring(lastIndex);
    const trailingPlain = this.getPlainTextFromHtml(trailing);
    if (trailingPlain.length > 0) {
      segments.push({ type: "text", text: trailingPlain });
    }
    if (segments.length > 0) return segments;
    // Fall through: try link detection
    const plain = this.getPlainTextFromHtml(content);
    const linkSegments = this.buildSegmentsWithLinks(plain);
    if (linkSegments && linkSegments.some((s) => s.type === "link")) {
      return linkSegments;
    }
    return null;
  }

  /**
   * Detect URLs in plain text and build segments (text + link) for link preview.
   * Returns null if no URLs so Apex uses content path.
   */
  buildSegmentsWithLinks(plainText) {
    if (!plainText || !plainText.trim()) return null;
    const urlRegex = /https?:\/\/[^\s<>"']+/g;
    const segments = [];
    let lastIndex = 0;
    let match;
    while ((match = urlRegex.exec(plainText)) !== null) {
      const before = plainText.substring(lastIndex, match.index);
      if (before.length > 0) {
        segments.push({ type: "text", text: before });
      }
      segments.push({ type: "link", url: match[0] });
      lastIndex = match.index + match[0].length;
    }
    const after = plainText.substring(lastIndex);
    if (after.length > 0) {
      segments.push({ type: "text", text: after });
    }
    return segments.length > 0 ? segments : null;
  }

  clearDraftFromLocalStorage() {
    try {
      const draftKey = this.getDraftKey();
      localStorage.removeItem(draftKey);
    } catch (error) {
      console.error("Error clearing draft from localStorage:", error);
    }
  }

  cleanupExpiredDrafts() {
    try {
      const keysToRemove = [];
      const prefixes = [DRAFT_KEY_PREFIX, POLL_DRAFT_KEY_PREFIX];

      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (!key) continue;
        const matchPrefix = prefixes.find((p) => key.startsWith(p));
        if (!matchPrefix) continue;
        const draftJson = localStorage.getItem(key);
        if (!draftJson) continue;
        try {
          const draft = JSON.parse(draftJson);
          if (this.isDraftExpired(draft.timestamp)) {
            keysToRemove.push(key);
          }
        } catch (e) {
          keysToRemove.push(key);
        }
      }
      keysToRemove.forEach((key) => localStorage.removeItem(key));
    } catch (error) {
      console.error("Error cleaning up expired drafts:", error);
    }
  }

  // Helper methods
  getDraftKey() {
    return DRAFT_KEY_PREFIX + this.effectiveGroupId;
  }

  isContentNotEmpty(content) {
    if (!content) {
      return false;
    }

    // Strip HTML tags and check if there's actual text content
    const tempDiv = document.createElement("div");
    // eslint-disable-next-line @lwc/lwc/no-inner-html
    tempDiv.innerHTML = content;
    const textContent = tempDiv.textContent || tempDiv.innerText || "";

    return textContent.trim().length > 0;
  }

  isDraftExpired(timestamp) {
    const draftDate = new Date(timestamp);
    const now = new Date();
    const daysDiff = (now - draftDate) / MS_PER_DAY;

    return daysDiff > DRAFT_EXPIRATION_DAYS;
  }

  getRelativeTime(timestamp) {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) {
      return "just now";
    }
    if (diffMins < 60) {
      return diffMins + " minute" + (diffMins === 1 ? "" : "s") + " ago";
    }
    if (diffHours < 24) {
      return diffHours + " hour" + (diffHours === 1 ? "" : "s") + " ago";
    }
    if (diffDays < 7) {
      return diffDays + " day" + (diffDays === 1 ? "" : "s") + " ago";
    }
    return date.toLocaleDateString();
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }

  get isPostDisabled() {
    const hasContent = this.isContentNotEmpty(this.draftContent);
    const hasSegments = this.postSegments && this.postSegments.length > 0;
    return this.isPosting || (!hasContent && !hasSegments);
  }

  get showCollapseOption() {
    if (this.activeTab === "question" && this.isExpanded) return true;
    return this.isExpanded && !this.isContentNotEmpty(this.draftContent);
  }
}
