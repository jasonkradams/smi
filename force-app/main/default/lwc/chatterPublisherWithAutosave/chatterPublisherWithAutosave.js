import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import postToChatter from "@salesforce/apex/ChatterPublisherController.postToChatter";

// Constants
const DRAFT_KEY_PREFIX = "chatterDraft_";
const AUTOSAVE_DELAY = 10000; // 10 seconds
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

  saveTimeout = null;
  hasUnsavedChanges = false;
  _internalGroupId = null;

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

  connectedCallback() {
    // If groupId is already set (via @api), load draft immediately
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

    // Clear any pending save timeout
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
    }
  }

  beforeUnloadHandler(event) {
    if (this.hasUnsavedChanges && this.isContentNotEmpty(this.draftContent)) {
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
    if (!this.isContentNotEmpty(this.draftContent)) {
      this.isExpanded = false;
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
    if (!this.effectiveGroupId) {
      return;
    }

    try {
      const draftKey = this.getDraftKey();
      const draftJson = localStorage.getItem(draftKey);

      if (draftJson) {
        const draft = JSON.parse(draftJson);

        // Check if draft is expired
        if (this.isDraftExpired(draft.timestamp)) {
          this.clearDraftFromLocalStorage();
          return;
        }

        this.savedDraft = draft;
        this.draftTimestamp = this.getRelativeTime(draft.timestamp);
        this.showRestoreDraftModal = true;
      }
    } catch (error) {
      console.error("Error loading draft from localStorage:", error);
    }
  }

  handleRestoreDraft() {
    if (this.savedDraft) {
      this.draftContent = this.savedDraft.content;
      this.hasDraft = true;
      this.hasUnsavedChanges = false;
      this.lastSavedText = "Draft restored from " + this.draftTimestamp;
      this.isExpanded = true;
    }
    this.showRestoreDraftModal = false;
  }

  handleDiscardDraft() {
    this.clearDraftFromLocalStorage();
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

      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);

        if (key && key.startsWith(DRAFT_KEY_PREFIX)) {
          const draftJson = localStorage.getItem(key);

          if (draftJson) {
            const draft = JSON.parse(draftJson);

            if (this.isDraftExpired(draft.timestamp)) {
              keysToRemove.push(key);
            }
          }
        }
      }

      // Remove expired drafts
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
