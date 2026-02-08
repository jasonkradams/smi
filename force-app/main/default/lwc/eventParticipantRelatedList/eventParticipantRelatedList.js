import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getEventParticipants from "@salesforce/apex/EventParticipantRedirectHelper.getEventParticipants";
import isEventLeader from "@salesforce/apex/EventParticipantRedirectHelper.isEventLeader";
import addParticipant from "@salesforce/apex/EventParticipantRedirectHelper.addParticipant";
import removeParticipant from "@salesforce/apex/EventParticipantRedirectHelper.removeParticipant";
import updateParticipantResponse from "@salesforce/apex/EventParticipantRedirectHelper.updateParticipantResponse";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";

export default class EventParticipantRelatedList extends NavigationMixin(
  LightningElement
) {
  @api objectApiName;
  @api recordId; // Event Id
  participants = [];
  isLoading = false;
  error;
  _eventIdFromUrl;
  _pageRef;
  _pageRefRecordId = null;
  _isLoadingParticipants = false; // Prevent duplicate calls
  _foundWorkingId = false; // Track if we found a working ID
  isEventLeader = false;
  eventRegistrationId = null;
  showAddParticipant = false;
  selectedContactId = null;
  selectedResponse = "Attending";
  responseOptions = [
    { label: "Attending", value: "Attending" },
    { label: "Not Attending", value: "Not Attending" }
  ];

  get effectiveRecordId() {
    return this.recordId || this._pageRefRecordId;
  }

  // Capture page reference for additional context
  @wire(CurrentPageReference)
  getPageReference(pageRef) {
    if (!pageRef || !pageRef.attributes || !pageRef.attributes.recordId) {
      // If no recordId from pageRef, try URL parsing as fallback
      if (
        !this.effectiveRecordId &&
        !this._eventIdFromUrl &&
        !this._isLoadingParticipants &&
        !this._foundWorkingId
      ) {
        // Small delay to let wire services initialize
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
          if (!this.effectiveRecordId && !this._foundWorkingId) {
            this.getEventIdFromUrl();
          }
        }, 100);
      }
      return;
    }

    this._pageRef = pageRef;
    const recordId = pageRef.attributes.recordId;

    // Set internal property so the @wire(getEventParticipants) can react via effectiveRecordId
    if (!this.recordId) {
      this._pageRefRecordId = recordId;
    }

    // Check if this is the same recordId we already processed
    const isNewRecordId = this._eventIdFromUrl !== recordId;

    // Only skip if it's the SAME event AND we already have participants for it
    // This prevents stale participants when navigating to a different event
    if (
      !isNewRecordId &&
      this._foundWorkingId &&
      this.participants.length > 0
    ) {
      return;
    }

    // Set the eventId for the new event
    this._eventIdFromUrl = recordId;

    // Don't manually load here - let the @wire(getEventParticipants) handle it
    // The wire service will react to this.recordId being set
  }

  connectedCallback() {
    // If we already have participants, don't try to load again
    if (this._foundWorkingId && this.participants.length > 0) {
      return;
    }

    // If we have a recordId from @api, the wire service will handle loading
    // Give wire services a chance to fire first
    if (this.effectiveRecordId) {
      // Wire service should handle this, but add a longer delay fallback
      // to give wire service time to complete
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        // Only fallback if wire service hasn't loaded data AND we're not currently loading
        if (
          !this._foundWorkingId &&
          !this._isLoadingParticipants &&
          this.effectiveRecordId &&
          this.participants.length === 0
        ) {
          // Fallback: if wire service didn't fire, load manually
          this.loadParticipants(this.effectiveRecordId);
        }
      }, 500);
      return;
    }

    // If no recordId, try URL parsing as fallback
    if (!this._eventIdFromUrl && !this._isLoadingParticipants) {
      // Small delay to let wire services initialize
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        if (
          !this.effectiveRecordId &&
          !this._foundWorkingId &&
          this.participants.length === 0
        ) {
          this.getEventIdFromUrl();
        }
      }, 100);
    }
  }

  // Removed tryAlternativeIdSources - it was causing duplicate loads and race conditions

  async getEventIdFromUrl() {
    // Don't proceed if we're already loading or have participants
    if (
      this._isLoadingParticipants ||
      (this._foundWorkingId && this.participants.length > 0)
    ) {
      return;
    }

    // Try to get Event ID from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const urlPath = window.location.pathname;

    let eventId = null;

    // Try URL parameters first
    eventId = urlParams.get("event") || urlParams.get("id");

    // Try Experience Cloud event registration pattern: /s/event-registration/[EventId]/[event-name]
    if (!eventId && urlPath.includes("/event-registration/")) {
      const pathParts = urlPath.split("/");
      const eventRegIndex = pathParts.indexOf("event-registration");
      if (eventRegIndex !== -1 && pathParts[eventRegIndex + 1]) {
        eventId = pathParts[eventRegIndex + 1];
      }
    }

    // Try generic event pattern: /event/[EventId]
    if (!eventId && urlPath.includes("/event/")) {
      const pathParts = urlPath.split("/");
      const eventIndex = pathParts.indexOf("event");
      if (eventIndex !== -1 && pathParts[eventIndex + 1]) {
        eventId = pathParts[eventIndex + 1];
      }
    }

    // If we found an eventId, check if it matches what we already have from pageRef
    if (eventId && this._eventIdFromUrl && eventId === this._eventIdFromUrl) {
      return;
    }

    // Try to decode/translate the ID if it looks like an Experience Cloud ID
    if (eventId && eventId.startsWith("a1") && !this._isLoadingParticipants) {
      await this.tryIdVariations(eventId);
    } else if (eventId && !this._isLoadingParticipants) {
      this._eventIdFromUrl = eventId;
      await this.loadParticipants(eventId);
    } else if (
      !eventId &&
      !this._foundWorkingId &&
      !this._isLoadingParticipants
    ) {
      this.error =
        "Unable to determine Event ID from URL. This component must be placed on an Event record page.";
    }
  }

  async tryIdVariations(originalId) {
    // Don't proceed if we're already loading or have participants
    if (
      this._isLoadingParticipants ||
      (this._foundWorkingId && this.participants.length > 0)
    ) {
      return;
    }

    // Try the original ID first
    await this.loadParticipants(originalId);

    // Only try variations if we didn't get participants
    if (
      this.participants.length === 0 &&
      !this._foundWorkingId &&
      !this._isLoadingParticipants
    ) {
      // Try common variations (case sensitivity, prefixes)
      const variations = [
        originalId.toUpperCase(),
        originalId.toLowerCase(),
        originalId.replace(/^a1/, "00U")
      ];

      // Try each variation sequentially (must be sequential to avoid race conditions)
      for (let i = 0; i < variations.length; i++) {
        // Stop if we found participants or started loading
        if (
          this._foundWorkingId ||
          this.participants.length > 0 ||
          this._isLoadingParticipants
        ) {
          break;
        }
        // eslint-disable-next-line no-await-in-loop
        await this.loadParticipants(variations[i]);
        // If we got participants, stop trying variations
        if (this.participants.length > 0 || this._foundWorkingId) {
          break;
        }
        // Small delay between attempts
        if (i < variations.length - 1) {
          // eslint-disable-next-line no-await-in-loop
          await new Promise((resolve) => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(resolve, 500);
          });
        }
      }
    }
  }

  async loadParticipants(eventId) {
    // Validate eventId
    if (!eventId) {
      return;
    }

    // Prevent duplicate calls
    if (this._isLoadingParticipants) {
      return;
    }

    // If we already have participants from wire service, don't overwrite with manual load
    if (this._foundWorkingId && this.participants.length > 0) {
      return;
    }

    // Set loading flag immediately to prevent race conditions
    this._isLoadingParticipants = true;
    this.isLoading = true;
    this.error = null;

    try {
      const participants = await getEventParticipants({ eventId: eventId });

      // Check if this is an Event_Registration__c by looking at the first participant's eventRegistrationId
      if (
        participants &&
        participants.length > 0 &&
        participants[0].eventRegistrationId
      ) {
        this.eventRegistrationId = participants[0].eventRegistrationId;
        try {
          this.isEventLeader = await isEventLeader({
            eventRegistrationId: this.eventRegistrationId
          });
        } catch (leaderErr) {
          console.error("Error checking leader status:", leaderErr);
          this.isEventLeader = false;
        }
      } else if (eventId && eventId.startsWith("a1")) {
        // If no participants but ID looks like Event_Registration__c, still check leader status
        this.eventRegistrationId = eventId;
        try {
          this.isEventLeader = await isEventLeader({
            eventRegistrationId: eventId
          });
        } catch (leaderErr) {
          console.error("Error checking leader status:", leaderErr);
          this.isEventLeader = false;
        }
      }

      // Only update if we got participants (don't overwrite with empty results)
      if (participants && participants.length > 0) {
        // Set loading to false first to ensure template updates correctly
        this.isLoading = false;
        this._isLoadingParticipants = false;

        // Create a new array reference to ensure LWC reactivity triggers
        this.participants = [...participants];

        this._eventIdFromUrl = eventId;
        this._foundWorkingId = true;
        this.error = null;
      } else if (this.participants.length === 0 && !this._foundWorkingId) {
        // Only set empty if we don't already have participants
        this.participants = [];
        this.isLoading = false;
        this._isLoadingParticipants = false;
      } else {
        // If we already have participants, just clear loading state
        this.isLoading = false;
        this._isLoadingParticipants = false;
      }
    } catch (err) {
      console.error("Error loading event participants:", err);
      // Only set error if we don't already have participants
      if (this.participants.length === 0) {
        this.error =
          "Unable to load event participants. Please try again later.";
      }
      this.isLoading = false;
      this._isLoadingParticipants = false;
    }
  }

  // Keep wire service for when recordId is available (for standard pages)
  @wire(getEventParticipants, { eventId: "$effectiveRecordId" })
  wiredParticipants({ error, data }) {
    // Use wire service when recordId or pageRef id is available
    if (this.effectiveRecordId) {
      this.wiredParticipantsHandler({ error, data });
    }
  }

  async wiredParticipantsHandler({ error, data }) {
    // If we already have participants from another source, don't overwrite
    // But allow updates if this is the same recordId (wire service refresh)
    if (
      this._foundWorkingId &&
      this.participants.length > 0 &&
      this._eventIdFromUrl !== this.effectiveRecordId
    ) {
      return;
    }

    if (data && data.length > 0) {
      // Stop any manual loading in progress
      this._isLoadingParticipants = false;
      this.isLoading = false;

      // Create a new array reference to ensure LWC reactivity triggers
      this.participants = [...data];
      this._foundWorkingId = true;
      this._eventIdFromUrl = this.effectiveRecordId;
      this.error = undefined;

      // Check if this is an Event_Registration__c and check leader status
      if (this.recordId) {
        this.eventRegistrationId = this.recordId;
        try {
          this.isEventLeader = await isEventLeader({
            eventRegistrationId: this.recordId
          });
        } catch (leaderErr) {
          console.error("Error checking leader status:", leaderErr);
          this.isEventLeader = false;
        }
      }
    } else if (error) {
      this._isLoadingParticipants = false;
      if (this.participants.length === 0) {
        this.error = error.body?.message || "Unable to load event participants";
      }
      this.isLoading = false;
    } else if (data !== undefined) {
      // Explicitly empty result (data is [] not undefined)
      this._isLoadingParticipants = false;
      if (this.participants.length === 0) {
        this.participants = [];
      }
      this.isLoading = false;
    }
    // If data is undefined, wire service is still loading - don't do anything
  }

  handleParticipantClick(event) {
    event.preventDefault();
    event.stopPropagation();

    const participantId = event.currentTarget.dataset.participantId;
    const hasUser =
      event.currentTarget.dataset.hasUser === "true" ||
      event.currentTarget.dataset.hasUser === true;

    if (hasUser && participantId) {
      // Navigate to User profile in Experience Cloud
      this[NavigationMixin.Navigate](
        {
          type: "standard__webPage",
          attributes: {
            url: `/s/profile/${participantId}`
          }
        },
        false
      );
    }
  }

  get showLoading() {
    return this.isLoading;
  }

  get showError() {
    return this.error;
  }

  get hasParticipants() {
    return this.participants && this.participants.length > 0;
  }

  get showLoadingAndNoParticipants() {
    return (
      this.isLoading && (!this.participants || this.participants.length === 0)
    );
  }

  get showErrorAndNoParticipants() {
    return this.error && (!this.participants || this.participants.length === 0);
  }

  get showEmptyState() {
    return (
      !this.isLoading &&
      !this.error &&
      (!this.participants || this.participants.length === 0)
    );
  }

  get participantCount() {
    return this.participants.length;
  }

  get participantCountLabel() {
    return `(${this.participants.length})`;
  }

  get scrollerMaxHeight() {
    // Calculate max-height based on participant count
    // ~40px per row (header ~40px + rows ~40px each)
    // Auto-size up to 20 participants, then apply max-height with scroll
    const participantCount = this.participants ? this.participants.length : 0;

    if (participantCount === 0) {
      // No participants - use min-height
      return "200px";
    }
    if (participantCount <= 20) {
      // Up to 20 participants - auto-size to fit all (no scroll)
      // Header: ~40px, each row: ~40px
      const calculatedHeight = 40 + participantCount * 40;
      return `${calculatedHeight}px`;
    }
    // More than 20 participants - max height for 20 rows, then scroll
    // 40px header + 20 rows * 40px = 840px
    return "840px";
  }

  get scrollerStyle() {
    return `max-height: ${this.scrollerMaxHeight};`;
  }

  handleAddParticipantClick() {
    this.showAddParticipant = true;
    this.selectedContactId = null;
    this.selectedResponse = "Attending";
  }

  handleCancelAdd() {
    this.showAddParticipant = false;
    this.selectedContactId = null;
  }

  handleContactChange(event) {
    this.selectedContactId = event.detail.recordId;
  }

  handleResponseChange(event) {
    this.selectedResponse = event.detail.value;
  }

  async handleSaveParticipant() {
    if (!this.selectedContactId) {
      this.showToast("Error", "Please select a contact to add.", "error");
      return;
    }

    if (!this.eventRegistrationId) {
      this.showToast("Error", "Event registration ID not found.", "error");
      return;
    }

    try {
      this.isLoading = true;
      const newParticipant = await addParticipant({
        eventRegistrationId: this.eventRegistrationId,
        contactId: this.selectedContactId,
        response: this.selectedResponse
      });

      // Add the new participant to the list
      this.participants = [...this.participants, newParticipant];
      this.showAddParticipant = false;
      this.selectedContactId = null;
      this.showToast("Success", "Participant added successfully.", "success");
    } catch (error) {
      console.error("Error adding participant:", error);
      this.showToast(
        "Error",
        error.body?.message || "Unable to add participant.",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleRemoveParticipant(event) {
    const participantId = event.currentTarget.dataset.participantId;
    if (!participantId || !this.eventRegistrationId) {
      return;
    }

    // eslint-disable-next-line no-alert, no-restricted-globals -- intentional confirm for remove participant
    if (!confirm("Are you sure you want to remove this participant?")) {
      return;
    }

    try {
      this.isLoading = true;
      await removeParticipant({
        participantId: participantId,
        eventRegistrationId: this.eventRegistrationId
      });

      // Remove the participant from the list
      this.participants = this.participants.filter(
        (p) => p.eventRelationId !== participantId
      );
      this.showToast("Success", "Participant removed successfully.", "success");
    } catch (error) {
      console.error("Error removing participant:", error);
      this.showToast(
        "Error",
        error.body?.message || "Unable to remove participant.",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleResponseChangeForParticipant(event) {
    const participantId = event.currentTarget.dataset.participantId;
    const newResponse = event.detail.value;

    if (!participantId) {
      this.showToast("Error", "Participant ID is missing.", "error");
      return;
    }

    if (!this.eventRegistrationId) {
      this.showToast(
        "Error",
        "Event Registration ID is missing. Please refresh the page.",
        "error"
      );
      return;
    }

    try {
      this.isLoading = true;
      const updatedParticipant = await updateParticipantResponse({
        participantId: participantId,
        eventRegistrationId: this.eventRegistrationId,
        response: newResponse
      });

      // Update the participant in the list
      this.participants = this.participants.map((p) => {
        return p.eventRelationId === participantId ? updatedParticipant : p;
      });
      this.showToast(
        "Success",
        "Participant response updated successfully.",
        "success"
      );
    } catch (error) {
      console.error("Error updating participant response:", error);
      this.showToast(
        "Error",
        error.body?.message ||
          error.message ||
          "Unable to update participant response.",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  showToast(title, message, variant) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(evt);
  }

  handleComboboxFocus(event) {
    // Find the parent row and add a class to increase z-index
    const combobox = event.currentTarget;
    const row = combobox.closest(".participant-row");
    if (row) {
      row.classList.add("combobox-active");
    }
  }

  handleComboboxBlur(event) {
    // Remove the class when combobox loses focus
    // Use setTimeout to allow dropdown click to register first
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      const combobox = event.currentTarget;
      const row = combobox.closest(".participant-row");
      if (row) {
        row.classList.remove("combobox-active");
      }
    }, 200);
  }
}
