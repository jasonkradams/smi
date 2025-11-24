import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createCase from '@salesforce/apex/TicketSubmissionHelper.createCase';
import getRecordTypes from '@salesforce/apex/TicketSubmissionHelper.getRecordTypes';
import getContactForUser from '@salesforce/apex/TicketSubmissionHelper.getContactForUser';

export default class TicketSubmissionForm extends NavigationMixin(LightningElement) {
    @track subject = '';
    @track description = '';
    @track selectedRecordType = '';
    @track selectedPriority = '';
    @track recordTypeOptions = [];
    @track priorityOptions = [
        { label: 'Low', value: 'Low' },
        { label: 'Medium', value: 'Medium' },
        { label: 'High', value: 'High' }
    ];
    @track isLoading = false;
    @track isFormVisible = false;
    error;

    connectedCallback() {
        this.checkContact();
        // Show form immediately when component loads (for dedicated Submit Ticket page)
        // The form will show if URL is /support/submit-ticket
        if (window.location.pathname && window.location.pathname.includes('/support/submit-ticket')) {
            this.isFormVisible = true;
        }
    }

    @wire(getRecordTypes)
    wiredRecordTypes({ error, data }) {
        if (data) {
            this.recordTypeOptions = data.map(rt => ({
                label: rt.label,
                value: rt.value
            }));
            this.error = null;
        } else if (error) {
            console.error('Error loading record types:', error);
            this.error = 'Unable to load ticket types. Please refresh the page.';
            this.recordTypeOptions = [];
        }
    }

    async checkContact() {
        try {
            const contactId = await getContactForUser();
            if (!contactId) {
                this.error = 'Unable to find your Contact record. Please contact support.';
            }
        } catch (error) {
            console.error('Error checking contact:', error);
            this.error = 'Unable to verify your account. Please contact support.';
        }
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handleRecordTypeChange(event) {
        this.selectedRecordType = event.detail.value;
    }

    handlePriorityChange(event) {
        this.selectedPriority = event.detail.value;
    }

    handleShowForm() {
        this.isFormVisible = true;
        this.error = null;
    }

    handleCancel() {
        this.isFormVisible = false;
        this.subject = '';
        this.description = '';
        this.selectedRecordType = '';
        this.selectedPriority = '';
        this.error = null;
    }

    validateForm() {
        if (!this.subject || this.subject.trim().length === 0) {
            this.showToast('Error', 'Please enter a subject for your ticket.', 'error');
            return false;
        }

        if (this.subject.length > 255) {
            this.showToast('Error', 'Subject must be 255 characters or less.', 'error');
            return false;
        }

        if (!this.description || this.description.trim().length < 10) {
            this.showToast('Error', 'Please enter a description (at least 10 characters).', 'error');
            return false;
        }

        if (!this.selectedRecordType) {
            this.showToast('Error', 'Please select a ticket type.', 'error');
            return false;
        }

        return true;
    }

    async handleSubmit() {
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;
        this.error = null;

        try {
            const caseRecord = await createCase({
                subject: this.subject.trim(),
                description: this.description.trim(),
                recordTypeId: this.selectedRecordType,
                priority: this.selectedPriority || null
            });

            this.showToast(
                'Success',
                `Ticket #${caseRecord.CaseNumber} has been created successfully!`,
                'success'
            );

            // Clear form
            this.subject = '';
            this.description = '';
            this.selectedRecordType = '';
            this.selectedPriority = '';
            this.isFormVisible = false;

            // Navigate to My Tickets page
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: `/support/my-tickets`
                }
            }, false);

        } catch (error) {
            console.error('Error creating ticket:', error);
            this.error = error.body?.message || error.message || 'An error occurred while creating your ticket. Please try again.';
            this.showToast('Error', this.error, 'error');
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

    get isFormValid() {
        return this.subject && 
               this.description && 
               this.description.length >= 10 && 
               this.selectedRecordType;
    }

    get isFormDisabled() {
        return this.isLoading || !this.isFormValid;
    }

    get descriptionLength() {
        return this.description ? this.description.length : 0;
    }

    get descriptionRemainingChars() {
        return Math.max(0, 10 - this.descriptionLength);
    }
}

