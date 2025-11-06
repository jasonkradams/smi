import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getEventParticipants from '@salesforce/apex/EventParticipantRedirectHelper.getEventParticipants';
import { CurrentPageReference } from 'lightning/navigation';

export default class EventParticipantRelatedList extends NavigationMixin(LightningElement) {
    @api objectApiName;
    @api recordId; // Event Id
    participants = [];
    isLoading = false;
    error;
    _eventIdFromUrl;
    _pageRef;
    _isLoadingParticipants = false; // Prevent duplicate calls
    _foundWorkingId = false; // Track if we found a working ID

    // Capture page reference for additional context
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (!pageRef || !pageRef.attributes || !pageRef.attributes.recordId) return;
        
        this._pageRef = pageRef;
        const recordId = pageRef.attributes.recordId;
        
        // Check if this is the same recordId we already processed
        const isNewRecordId = this._eventIdFromUrl !== recordId;
        
        // Only skip if it's the SAME event AND we already have participants for it
        // This prevents stale participants when navigating to a different event
        if (!isNewRecordId && this._foundWorkingId && this.participants.length > 0) {
            return;
        }
        
        // Set the eventId for the new event
        this._eventIdFromUrl = recordId;
        
        // Only load if we're not already loading
        if (!this._isLoadingParticipants) {
            this.loadParticipants(recordId);
        }
    }

    connectedCallback() {
        // If we already have participants or are loading, don't try to load again
        if (this._foundWorkingId && this.participants.length > 0) {
            return;
        }
        
        if (this._isLoadingParticipants) {
            return;
        }
        
        // If we have a recordId from page context, use it immediately
        if (this.recordId) {
            this.loadParticipants(this.recordId);
            return;
        }
        
        // Only try URL if we don't have a pageRef recordId already
        if (!this._eventIdFromUrl && !this._isLoadingParticipants) {
            this.getEventIdFromUrl();
        }
    }

    // Removed tryAlternativeIdSources - it was causing duplicate loads and race conditions

    async getEventIdFromUrl() {
        // Don't proceed if we're already loading or have participants
        if (this._isLoadingParticipants || (this._foundWorkingId && this.participants.length > 0)) {
            return;
        }
        
        // Try to get Event ID from URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const urlPath = window.location.pathname;
        
        let eventId = null;
        
        // Try URL parameters first
        eventId = urlParams.get('event') || urlParams.get('id');
        
        // Try Experience Cloud event registration pattern: /s/event-registration/[EventId]/[event-name]
        if (!eventId && urlPath.includes('/event-registration/')) {
            const pathParts = urlPath.split('/');
            const eventRegIndex = pathParts.indexOf('event-registration');
            if (eventRegIndex !== -1 && pathParts[eventRegIndex + 1]) {
                eventId = pathParts[eventRegIndex + 1];
            }
        }
        
        // Try generic event pattern: /event/[EventId]
        if (!eventId && urlPath.includes('/event/')) {
            const pathParts = urlPath.split('/');
            const eventIndex = pathParts.indexOf('event');
            if (eventIndex !== -1 && pathParts[eventIndex + 1]) {
                eventId = pathParts[eventIndex + 1];
            }
        }
        
        // If we found an eventId, check if it matches what we already have from pageRef
        if (eventId && this._eventIdFromUrl && eventId === this._eventIdFromUrl) {
            return;
        }
        
        // Try to decode/translate the ID if it looks like an Experience Cloud ID
        if (eventId && eventId.startsWith('a1') && !this._isLoadingParticipants) {
            await this.tryIdVariations(eventId);
        } else if (eventId && !this._isLoadingParticipants) {
            this._eventIdFromUrl = eventId;
            await this.loadParticipants(eventId);
        } else if (!eventId && !this._foundWorkingId && !this._isLoadingParticipants) {
            this.error = 'Unable to determine Event ID from URL. This component must be placed on an Event record page.';
        }
    }
    
    async tryIdVariations(originalId) {
        // Don't proceed if we're already loading or have participants
        if (this._isLoadingParticipants || (this._foundWorkingId && this.participants.length > 0)) {
            return;
        }
        
        // Try the original ID first
        await this.loadParticipants(originalId);
        
        // Only try variations if we didn't get participants
        if (this.participants.length === 0 && !this._foundWorkingId && !this._isLoadingParticipants) {
            // Try common variations (case sensitivity, prefixes)
            const variations = [
                originalId.toUpperCase(),
                originalId.toLowerCase(),
                originalId.replace(/^a1/, '00U')
            ];
            
            // Try each variation sequentially
            for (let i = 0; i < variations.length; i++) {
                // Stop if we found participants or started loading
                if (this._foundWorkingId || this.participants.length > 0 || this._isLoadingParticipants) {
                    break;
                }
                
                await this.loadParticipants(variations[i]);
                
                // If we got participants, stop trying variations
                if (this.participants.length > 0 || this._foundWorkingId) {
                    break;
                }
                
                // Small delay between attempts
                if (i < variations.length - 1) {
                    await new Promise(resolve => setTimeout(resolve, 500));
                }
            }
        }
    }

    async loadParticipants(eventId) {
        // Validate eventId
        if (!eventId) return;
        
        // Prevent duplicate calls
        if (this._isLoadingParticipants) return;
        
        // If we already have participants, don't try again
        if (this._foundWorkingId && this.participants.length > 0) return;
        
        // Set loading flag immediately to prevent race conditions
        this._isLoadingParticipants = true;
        this.isLoading = true;
        this.error = null;

        try {
            const participants = await getEventParticipants({ eventId: eventId });
            
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
            console.error('Error loading event participants:', err);
            // Only set error if we don't already have participants
            if (this.participants.length === 0) {
                this.error = 'Unable to load event participants. Please try again later.';
            }
            this.isLoading = false;
            this._isLoadingParticipants = false;
        }
    }

    // Keep wire service for when recordId is available (for standard pages)
    @wire(getEventParticipants, { eventId: '$recordId' })
    wiredParticipants({ error, data }) {
        // Only use wire service if we have recordId AND haven't already loaded participants
        // AND we're not currently loading (prevents race conditions with manual loads)
        if (this.recordId && !this._foundWorkingId && !this._isLoadingParticipants) {
            this.wiredParticipantsHandler({ error, data });
        }
    }

    wiredParticipantsHandler({ error, data }) {
        // If we already have participants from another source, don't overwrite
        if (this._foundWorkingId && this.participants.length > 0) {
            return;
        }
        
        if (data && data.length > 0) {
            // Create a new array reference to ensure LWC reactivity triggers
            this.participants = [...data];
            this._foundWorkingId = true;
            this.error = undefined;
        } else if (error) {
            if (this.participants.length === 0) {
                this.error = error.body?.message || 'Unable to load event participants';
            }
        } else {
            if (this.participants.length === 0) {
                this.participants = [];
            }
        }
        this.isLoading = false;
    }

    handleParticipantClick(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const participantId = event.currentTarget.dataset.participantId;
        const hasUser = event.currentTarget.dataset.hasUser === 'true' || event.currentTarget.dataset.hasUser === true;
        
        if (hasUser && participantId) {
            // Navigate to User profile in Experience Cloud
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: `/s/profile/${participantId}`
                }
            }, false);
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
        return this.isLoading && (!this.participants || this.participants.length === 0);
    }

    get showErrorAndNoParticipants() {
        return this.error && (!this.participants || this.participants.length === 0);
    }

    get showEmptyState() {
        return !this.isLoading && !this.error && (!this.participants || this.participants.length === 0);
    }

    get participantCount() {
        return this.participants.length;
    }

    get participantCountLabel() {
        return `(${this.participants.length})`;
    }
}

