import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getTicketDetails from '@salesforce/apex/TicketQueryHelper.getTicketDetails';
import getTicketComments from '@salesforce/apex/TicketQueryHelper.getTicketComments';
import addComment from '@salesforce/apex/TicketSubmissionHelper.addComment';

export default class TicketDetail extends NavigationMixin(LightningElement) {
    @api recordId; // Case ID
    @track ticket;
    @track comments = [];
    @track newComment = '';
    @track isLoading = false;
    @track isAddingComment = false;
    @track error;
    wiredTicketResult;
    wiredCommentsResult;

    @wire(getTicketDetails, { caseId: '$recordId' })
    wiredTicket(result) {
        this.wiredTicketResult = result;
        const { data, error } = result;
        
        if (data) {
            // Format dates and add badge variant properties
            this.ticket = {
                ...data,
                formattedCreatedDate: this.formatDateValue(data.CreatedDate),
                formattedLastModifiedDate: this.formatDateValue(data.LastModifiedDate),
                statusBadgeVariant: this.getStatusBadgeVariant(data.Status),
                priorityBadgeVariant: this.getPriorityBadgeVariant(data.Priority)
            };
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body?.message || 'Unable to load ticket details';
            this.ticket = undefined;
            this.isLoading = false;
        } else {
            this.isLoading = true;
        }
    }

    @wire(getTicketComments, { caseId: '$recordId' })
    wiredComments(result) {
        this.wiredCommentsResult = result;
        const { data, error } = result;
        
        if (data) {
            // Format dates for each comment
            this.comments = data.map(comment => ({
                ...comment,
                formattedCreatedDate: this.formatLongDateValue(comment.CreatedDate)
            }));
        } else if (error) {
            console.error('Error loading comments:', error);
        }
    }

    handleCommentChange(event) {
        this.newComment = event.target.value;
    }

    async handleAddComment() {
        if (!this.newComment || this.newComment.trim().length === 0) {
            this.showToast('Error', 'Please enter a comment.', 'error');
            return;
        }

        if (!this.recordId) {
            this.showToast('Error', 'Ticket ID is missing.', 'error');
            return;
        }

        this.isAddingComment = true;
        this.error = null;

        try {
            await addComment({
                caseId: this.recordId,
                commentBody: this.newComment.trim()
            });

            this.showToast('Success', 'Comment added successfully.', 'success');
            this.newComment = '';
            
            // Refresh comments
            await refreshApex(this.wiredCommentsResult);
            
            // Optionally refresh ticket to get updated LastModifiedDate
            await refreshApex(this.wiredTicketResult);
            
        } catch (error) {
            console.error('Error adding comment:', error);
            this.error = error.body?.message || error.message || 'An error occurred while adding your comment.';
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isAddingComment = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredTicketResult),
                refreshApex(this.wiredCommentsResult)
            ]);
            this.showToast('Success', 'Ticket refreshed.', 'success');
        } catch (error) {
            this.showToast('Error', 'Unable to refresh ticket. Please try again.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/support/my-tickets'
            }
        }, false);
    }

    get canAddComment() {
        return this.ticket && 
               this.ticket.Status !== 'Closed' && 
               this.ticket.Status !== 'Resolved' &&
               this.newComment && 
               this.newComment.trim().length > 0 &&
               !this.isAddingComment;
    }

    get isAddCommentDisabled() {
        return !this.canAddComment;
    }

    get isTicketClosed() {
        return this.ticket && 
               (this.ticket.Status === 'Closed' || this.ticket.Status === 'Resolved');
    }

    get statusBadgeVariant() {
        if (!this.ticket) return 'default';
        return this.getStatusBadgeVariant(this.ticket.Status);
    }

    getStatusBadgeVariant(status) {
        if (status === 'Closed' || status === 'Resolved') {
            return 'success';
        } else if (status === 'In Progress' || status === 'Waiting for Member') {
            return 'warning';
        } else {
            return 'info';
        }
    }

    getPriorityBadgeVariant(priority) {
        if (!priority) return 'default';
        if (priority === 'High') {
            return 'error';
        } else if (priority === 'Medium') {
            return 'warning';
        } else {
            return 'default';
        }
    }

    formatDateValue(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    }

    formatLongDateValue(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleString();
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    get hasComments() {
        return this.comments && this.comments.length > 0;
    }

    get commentCount() {
        return this.comments ? this.comments.length : 0;
    }
}

