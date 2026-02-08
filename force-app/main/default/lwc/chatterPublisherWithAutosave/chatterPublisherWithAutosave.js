import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import postToChatter from "@salesforce/apex/ChatterPublisherController.postToChatter";
import postPollToChatter from "@salesforce/apex/ChatterPublisherController.postPollToChatter";

// Constants
const DRAFT_KEY_PREFIX = "chatterDraft_";
const POLL_DRAFT_KEY_PREFIX = "chatterPollDraft_";
const AUTOSAVE_DELAY = 1000; // 1 second
const DRAFT_EXPIRATION_DAYS = 7;

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
  pollChoices = [
    { id: "1", value: "", canRemove: false },
    { id: "2", value: "", canRemove: false }
  ];
  _pollChoiceId = 3;
  MAX_POLL_CHOICES = 10;

  saveTimeout = null;
  pollSaveTimeout = null;
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

  get isPostTabActive() {
    return this.activeTab === "post";
  }

  get isPollTabActive() {
    return this.activeTab === "poll";
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
    }, AUTOSAVE_DELAY);
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

    // Clear existing timeout
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
    }

    // Use promise-based approach for autosave to avoid async operation restriction
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.saveTimeout = setTimeout(() => {
      this.saveDraftToLocalStorage();
    }, AUTOSAVE_DELAY);
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
        groupId: this.effectiveGroupId
      };

      localStorage.setItem(draftKey, JSON.stringify(draft));

      this.lastSavedText =
        "Draft saved " + this.getRelativeTime(draft.timestamp);
      this.hasUnsavedChanges = false;
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
    if (!this.isContentNotEmpty(this.draftContent)) {
      this.showToast("Error", "Please enter some content to share", "error");
      return;
    }

    if (!this.effectiveGroupId) {
      this.showToast("Error", "Unable to determine group ID", "error");
      return;
    }

    this.isPosting = true;

    try {
      await postToChatter({
        groupId: this.effectiveGroupId,
        content: this.draftContent
      });

      this.showToast("Success", "Your post has been shared", "success");

      // Clear draft after successful post and collapse
      this.draftContent = "";
      this.hasDraft = false;
      this.hasUnsavedChanges = false;
      this.lastSavedText = "";
      this.isExpanded = false;
      this.clearDraftFromLocalStorage();

      // Refresh the feed (dispatch event for parent components to listen)
      this.dispatchEvent(new CustomEvent("postpublished"));

      // Reload the page to show the new post
      window.location.reload();
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
    const daysDiff = (now - draftDate) / (1000 * 60 * 60 * 24);

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
    return this.isPosting || !this.isContentNotEmpty(this.draftContent);
  }

  get showCollapseOption() {
    return this.isExpanded && !this.isContentNotEmpty(this.draftContent);
  }
}
