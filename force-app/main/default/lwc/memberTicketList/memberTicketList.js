import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getMyTickets from '@salesforce/apex/TicketQueryHelper.getMyTickets';

export default class MemberTicketList extends NavigationMixin(LightningElement) {
    @track tickets = [];
    @track filteredTickets = [];
    @track selectedStatusFilter = 'All';
    @track selectedRecordTypeFilter = 'All';
    @track isLoading = false;
    error;
    wiredTicketsResult;

    statusFilterOptions = [
        { label: 'All', value: 'All' },
        { label: 'Open', value: 'Open' },
        { label: 'Closed', value: 'Closed' }
    ];

    @wire(getMyTickets)
    wiredTickets(result) {
        this.wiredTicketsResult = result;
        const { data, error } = result;
        
        if (data) {
            // Format dates and add badge variant properties to each ticket
            this.tickets = data.map(ticket => ({
                ...ticket,
                formattedCreatedDate: this.formatDateValue(ticket.CreatedDate),
                formattedLastModifiedDate: this.formatDateValue(ticket.LastModifiedDate),
                statusBadgeVariant: this.getStatusBadgeVariant(ticket.Status),
                priorityBadgeVariant: this.getPriorityBadgeVariant(ticket.Priority)
            }));
            this.filteredTickets = this.tickets;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body?.message || 'Unable to load tickets';
            this.tickets = [];
            this.filteredTickets = [];
            this.isLoading = false;
        } else {
            this.isLoading = true;
        }
    }

    handleStatusFilterChange(event) {
        this.selectedStatusFilter = event.detail.value;
        this.applyFilters();
    }

    handleRecordTypeFilterChange(event) {
        this.selectedRecordTypeFilter = event.detail.value;
        this.applyFilters();
    }

    applyFilters() {
        this.filteredTickets = this.tickets.filter(ticket => {
            // Status filter
            if (this.selectedStatusFilter === 'Open') {
                if (ticket.Status === 'Closed' || ticket.Status === 'Resolved') {
                    return false;
                }
            } else if (this.selectedStatusFilter === 'Closed') {
                if (ticket.Status !== 'Closed' && ticket.Status !== 'Resolved') {
                    return false;
                }
            }
            
            // Record type filter
            if (this.selectedRecordTypeFilter !== 'All') {
                if (ticket.RecordType.DeveloperName !== this.selectedRecordTypeFilter) {
                    return false;
                }
            }
            
            return true;
        });
    }
    
    formatDateValue(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString();
    }

    handleTicketClick(event) {
        const caseId = event.currentTarget.dataset.caseId;
        if (caseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: `/support/ticket/${caseId}`
                }
            }, false);
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredTicketsResult);
        } catch (error) {
            this.showToast('Error', 'Unable to refresh tickets. Please try again.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get hasTickets() {
        return this.filteredTickets && this.filteredTickets.length > 0;
    }

    get ticketCount() {
        return this.filteredTickets ? this.filteredTickets.length : 0;
    }

    get ticketCountLabel() {
        return this.ticketCount !== 1 ? 's' : '';
    }

    get recordTypeFilterOptions() {
        const recordTypes = new Set();
        if (this.tickets && this.tickets.length > 0) {
            this.tickets.forEach(ticket => {
                if (ticket.RecordType && ticket.RecordType.DeveloperName) {
                    recordTypes.add(ticket.RecordType.DeveloperName);
                }
            });
        }
        
        const options = [{ label: 'All', value: 'All' }];
        Array.from(recordTypes).forEach(rt => {
            const ticket = this.tickets.find(t => t.RecordType.DeveloperName === rt);
            if (ticket && ticket.RecordType) {
                options.push({
                    label: ticket.RecordType.Name,
                    value: rt
                });
            }
        });
        
        return options;
    }

    get statusBadgeVariant() {
        const variants = {
            'New': 'info',
            'In Progress': 'warning',
            'Closed': 'success',
            'Resolved': 'success',
            'Waiting for Member': 'warning'
        };
        return variants;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
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
        if (priority === 'High') {
            return 'error';
        } else if (priority === 'Medium') {
            return 'warning';
        } else {
            return 'default';
        }
    }

}

