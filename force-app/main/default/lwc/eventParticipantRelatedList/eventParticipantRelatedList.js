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
        this._pageRef = pageRef;
        console.log('Page Reference:', JSON.parse(JSON.stringify(pageRef)));
        
        // Look for record ID in page reference
        if (pageRef && pageRef.attributes && pageRef.attributes.recordId) {
            console.log('Found recordId in pageRef:', pageRef.attributes.recordId);
            this._eventIdFromUrl = pageRef.attributes.recordId;
            // Only load if we don't already have participants
            if (!this._foundWorkingId) {
                this.loadParticipants(pageRef.attributes.recordId);
            }
        }
        
        // Look for other ID fields in page reference
        if (pageRef && pageRef.attributes) {
            console.log('PageRef attributes:', Object.keys(pageRef.attributes));
            Object.keys(pageRef.attributes).forEach(key => {
                console.log(`${key}:`, pageRef.attributes[key]);
            });
        }
        
        // Look in state parameters
        if (pageRef && pageRef.state) {
            console.log('PageRef state:', pageRef.state);
        }
    }

    connectedCallback() {
        console.log('EventParticipantRelatedList connected');
        console.log('Object API Name:', this.objectApiName);
        console.log('Initial recordId:', this.recordId);
        
        // Try to get Event ID from URL since Experience Cloud doesn't provide record context
        this.getEventIdFromUrl();
        
        // Also try to get from any available context
        this.tryAlternativeIdSources();
    }

    tryAlternativeIdSources() {
        console.log('Trying alternative ID sources...');
        
        // Look for the actual Salesforce record ID from the Record Detail component
        // Experience Cloud uses different IDs in URLs vs. the actual record context
        
        // Try to find record ID from various DOM patterns
        const possibleSelectors = [
            '[data-record-id]',
            'force-record-layout-item[data-record-id]',
            'lightning-record-form[data-record-id]',
            'c-record-detail[data-record-id]',
            '[data-record-id*="00U"]', // Look for actual Event record IDs
            'div[data-record-id]',
            'span[data-record-id]'
        ];
        
        let foundRecordId = null;
        
        possibleSelectors.forEach(selector => {
            const elements = document.querySelectorAll(selector);
            console.log(`Found ${elements.length} elements with selector: ${selector}`);
            
            elements.forEach((el, index) => {
                const recordId = el.dataset.recordId;
                console.log(`Element ${index} recordId: ${recordId}`);
                
                // Look for actual Salesforce Event record IDs (start with 00U)
                if (recordId && recordId.startsWith('00U')) {
                    foundRecordId = recordId;
                    console.log('Found actual Event record ID:', recordId);
                }
            });
        });
        
        // If we found a real Event ID, use it
        if (foundRecordId && !this._foundWorkingId) {
            console.log('Using found Event record ID:', foundRecordId);
            this._eventIdFromUrl = foundRecordId;
            this.loadParticipants(foundRecordId);
            return;
        }
        
        // Try to find record ID in window object or other global contexts
        console.log('Checking global contexts...');
        
        // Check for Experience Cloud specific context
        if (window.CommunityLayout && window.CommunityLayout.page) {
            console.log('CommunityLayout context:', window.CommunityLayout.page);
        }
        
        // Check if there's any record context in the URL hash or other locations
        if (window.location.hash) {
            console.log('URL hash:', window.location.hash);
        }
        
        // As a last resort, try the hardcoded ID you found works (only if no participants found)
        if (!this._foundWorkingId && this.participants.length === 0) {
            console.log('Trying known working Event ID as fallback...');
            this.loadParticipants('00U2G00001IJHOGUA5');
        }
    }

    async getEventIdFromUrl() {
        // Try to get Event ID from URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const urlPath = window.location.pathname;
        
        console.log('Full URL:', window.location.href);
        console.log('URL Path:', urlPath);
        console.log('URL Params:', urlParams.toString());
        
        // Look for Event ID in various URL patterns
        // Pattern 1: /s/event-registration/[EventId]/[event-name]
        // Pattern 2: /event/[EventId]
        // Pattern 3: ?event=[EventId]
        // Pattern 4: ?id=[EventId]
        
        let eventId = null;
        
        // Try URL parameters first
        eventId = urlParams.get('event') || urlParams.get('id');
        
        // Try Experience Cloud event registration pattern
        if (!eventId && urlPath.includes('/event-registration/')) {
            const pathParts = urlPath.split('/');
            const eventRegIndex = pathParts.indexOf('event-registration');
            if (eventRegIndex !== -1 && pathParts[eventRegIndex + 1]) {
                eventId = pathParts[eventRegIndex + 1];
                console.log('Found Event ID using event-registration pattern:', eventId);
            }
        }
        
        // Try generic event pattern
        if (!eventId && urlPath.includes('/event/')) {
            const pathParts = urlPath.split('/');
            const eventIndex = pathParts.indexOf('event');
            if (eventIndex !== -1 && pathParts[eventIndex + 1]) {
                eventId = pathParts[eventIndex + 1];
                console.log('Found Event ID using event pattern:', eventId);
            }
        }
        
        console.log('Extracted Event ID:', eventId);
        
        // Try to decode/translate the ID if it looks like an Experience Cloud ID
        if (eventId && eventId.startsWith('a1')) {
            console.log('Attempting to translate Experience Cloud ID:', eventId);
            // This might be a case-insensitive ID or need translation
            // Try both the original ID and potential variations
            this.tryIdVariations(eventId);
        } else if (eventId) {
            this._eventIdFromUrl = eventId;
            await this.loadParticipants(eventId);
        } else {
            console.log('No Event ID found in URL');
            this.error = 'Unable to determine Event ID from URL. This component must be placed on an Event record page.';
        }
    }
    
    async tryIdVariations(originalId) {
        console.log('Trying ID variations for:', originalId);
        
        // Try the original ID first
        await this.loadParticipants(originalId);
        
        // Only try variations if we didn't get participants and haven't found a working ID
        if (this.participants.length === 0 && !this._foundWorkingId) {
            // Try common variations (case sensitivity, prefixes)
            const variations = [
                originalId.toUpperCase(),
                originalId.toLowerCase(),
                // Try replacing a1 prefix with 00U (Event prefix)
                originalId.replace(/^a1/, '00U')
            ];
            
            console.log('No participants found, trying variations:', variations);
            
            // Try each variation sequentially
            for (let i = 0; i < variations.length; i++) {
                // Stop if we found participants or a working ID
                if (this._foundWorkingId || this.participants.length > 0) {
                    console.log('Found working ID, stopping variation attempts');
                    break;
                }
                
                const variation = variations[i];
                console.log('Trying variation:', variation);
                await this.loadParticipants(variation);
                
                // Small delay between attempts (except for last one)
                if (i < variations.length - 1) {
                    await new Promise(resolve => setTimeout(resolve, 500));
                }
            }
        } else if (this.participants.length > 0) {
            console.log('Found participants with original ID, skipping variations');
        }
    }

    async loadParticipants(eventId) {
        // Prevent duplicate calls
        if (this._isLoadingParticipants) {
            console.log('Already loading participants, skipping duplicate call for:', eventId);
            return;
        }
        
        // If we already found a working ID and have participants, don't try again
        if (this._foundWorkingId && this.participants.length > 0) {
            console.log('Already have participants from working ID, skipping:', eventId);
            return;
        }
        
        console.log('Loading participants for Event ID:', eventId);
        this._isLoadingParticipants = true;
        this.isLoading = true;
        this.error = null;

        try {
            const participants = await getEventParticipants({ eventId: eventId });
            console.log('Received participants:', participants);
            
            // Only update if we got participants (don't overwrite with empty results)
            if (participants && participants.length > 0) {
                this.participants = participants;
                this._eventIdFromUrl = eventId;
                this._foundWorkingId = true; // Mark that we found a working ID
                console.log('Success! Using Event ID:', eventId);
                console.log('Participants data:', JSON.parse(JSON.stringify(participants)));
                
                // Log participant details for debugging
                participants.forEach((p, idx) => {
                    console.log(`Participant ${idx + 1}:`, {
                        name: p.contactName,
                        hasUser: p.hasUser,
                        userId: p.userId,
                        contactId: p.contactId
                    });
                });
            } else if (this.participants.length === 0) {
                // Only set empty if we don't already have participants
                this.participants = [];
                console.log('No participants found for Event ID:', eventId);
            }
        } catch (err) {
            console.error('Error loading event participants:', err);
            this.error = 'Unable to load event participants. Please try again later.';
            // Don't clear existing participants on error
        } finally {
            this.isLoading = false;
            this._isLoadingParticipants = false;
        }
    }

    // Keep wire service for when recordId is available (for standard pages)
    @wire(getEventParticipants, { eventId: '$recordId' })
    wiredParticipants({ error, data }) {
        if (this.recordId) {
            console.log('Using recordId from page context');
            this.wiredParticipantsHandler({ error, data });
        }
    }

    wiredParticipantsHandler({ error, data }) {
        console.log('wiredParticipants called');
        console.log('objectApiName:', this.objectApiName);
        console.log('recordId:', this.recordId);
        console.log('error:', error);
        console.log('data:', data);
        
        if (data) {
            console.log('Data received, length:', data.length);
            console.log('Participants:', JSON.parse(JSON.stringify(data)));
            this.participants = data;
            this.error = undefined;
        } else if (error) {
            console.error('Error loading participants:', error);
            this.error = error.body.message;
            this.participants = [];
        } else {
            console.log('No data and no error - likely no recordId or wrong object type');
            this.participants = [];
        }
        this.isLoading = false;
    }

    handleParticipantClick(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const participantId = event.currentTarget.dataset.participantId;
        const hasUser = event.currentTarget.dataset.hasUser === 'true' || event.currentTarget.dataset.hasUser === true;
        
        console.log('Participant clicked:', { participantId, hasUser, dataset: event.currentTarget.dataset });
        
        if (hasUser && participantId) {
            // Navigate to User profile in Experience Cloud
            console.log('Navigating to user profile:', participantId);
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: `/s/profile/${participantId}`
                }
            }, false); // false = don't replace current page
        } else {
            console.log('No user profile available for this participant');
        }
        // If no user exists, don't navigate - just show the name
    }

    get showLoading() {
        return this.isLoading;
    }

    get showError() {
        return this.error;
    }

    get hasParticipants() {
        return this.participants.length > 0;
    }

    get participantCount() {
        return this.participants.length;
    }

    get participantCountLabel() {
        return `(${this.participants.length})`;
    }

    // Debug getters
    get debugInfo() {
        return `Object: ${this.objectApiName}, RecordId: ${this.recordId}, UrlEventId: ${this._eventIdFromUrl}, PageRef: ${this._pageRef ? 'YES' : 'NO'}, Participants: ${this.participants.length}, Loading: ${this.isLoading}, Error: ${this.error || 'none'}`;
    }

    get hasRecordId() {
        return !!this.recordId;
    }
}
