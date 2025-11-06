import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getUserRedirectUrl from '@salesforce/apex/EventParticipantRedirectHelper.getUserRedirectUrl';

export default class EventParticipantRedirect extends NavigationMixin(LightningElement) {
    @api recordId;
    @api contactName;
    isLoading = false;
    errorMessage;

    connectedCallback() {
        this.checkRedirect();
    }

    async checkRedirect() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = null;

        try {
            const redirectUrl = await getUserRedirectUrl({ eventRelationId: this.recordId });
            
            if (redirectUrl) {
                // Navigate to user profile
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: redirectUrl
                    }
                });
            } else {
                // Show no profile message
                this.errorMessage = 'This participant has no public profile available.';
            }
        } catch (error) {
            console.error('Error checking redirect:', error);
            this.errorMessage = 'An error occurred while checking for user profile.';
        } finally {
            this.isLoading = false;
        }
    }

    handleContactClick(event) {
        event.preventDefault();
        this.checkRedirect();
    }

    get showLoading() {
        return this.isLoading;
    }

    get showError() {
        return this.errorMessage;
    }
}
