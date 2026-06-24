import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

export default class Tat extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api deadlineFieldApiName = 'SLA_Deadline__c';
    @api startDateFieldApiName = 'CreatedDate';
    @api tier2DeadlineFieldApiName = 'SLA_Tier_2_Deadline__c';
    @api tier3DeadlineFieldApiName = 'SLA_Tier_3_Deadline__c';
    @api escalationTierFieldApiName = 'SLA_Escalation_Tier__c';

    @track timeLeftText = '';
    @track countdownTimer = '';
    @track percentage = 0;
    @track slaStatusText = 'Safe';
    @track formattedDueDate = '';
    @track formattedCreatedDate = '';
    @track tierLabel = 'SLA Deadline';
    
    // Status colors
    @track circleColor = '#4bca81'; // Green default
    @track statusColorClass = 'status-green';

    deadline;
    startDate;
    timer;
    isFullyBreached = false;

    get fields() {
        if (this.objectApiName && this.deadlineFieldApiName && this.startDateFieldApiName) {
            return [
                `${this.objectApiName}.${this.deadlineFieldApiName}`,
                `${this.objectApiName}.${this.startDateFieldApiName}`,
                `${this.objectApiName}.${this.tier2DeadlineFieldApiName}`,
                `${this.objectApiName}.${this.tier3DeadlineFieldApiName}`,
                `${this.objectApiName}.${this.escalationTierFieldApiName}`
            ];
        }
        return [];
    }

    @wire(getRecord, { recordId: '$recordId', fields: '$fields' })
    wiredRecord({ error, data }) {
        if (data) {
            const t1Deadline = getFieldValue(data, this.fields[0]);
            const startDateValue = getFieldValue(data, this.fields[1]);
            const t2Deadline = getFieldValue(data, this.fields[2]);
            const t3Deadline = getFieldValue(data, this.fields[3]);
            const escTier = getFieldValue(data, this.fields[4]) || 0;

            if (t1Deadline && startDateValue) {
                if (escTier === 0) {
                    this.deadline = new Date(t1Deadline).getTime();
                    this.startDate = new Date(startDateValue).getTime();
                    this.tierLabel = 'Tier 1 Deadline';
                } else if (escTier === 1 && t2Deadline) {
                    this.deadline = new Date(t2Deadline).getTime();
                    this.startDate = new Date(t1Deadline).getTime();
                    this.tierLabel = 'Tier 2 Deadline';
                } else if (escTier === 2 && t3Deadline) {
                    this.deadline = new Date(t3Deadline).getTime();
                    this.startDate = new Date(t2Deadline).getTime();
                    this.tierLabel = 'Tier 3 Deadline';
                } else if (escTier >= 3) {
                    this.isFullyBreached = true;
                }
                
                // Format dates for display (show the current active deadline)
                if (!this.isFullyBreached) {
                    this.formattedDueDate = this.formatDate(this.deadline);
                    this.formattedCreatedDate = this.formatDate(this.startDate);
                    this.startTimer();
                } else {
                    this.timeLeftText = '0 Mins';
                    this.countdownTimer = '0h 0m 0s';
                    this.percentage = 0;
                    this.slaStatusText = 'Max Breach';
                    this.circleColor = '#ba0517';
                    this.statusColorClass = 'status-red';
                    this.clearIntervals();
                }
            } else {
                this.timeLeftText = 'No SLA Set';
                this.percentage = 0;
                this.clearIntervals();
            }
        } else if (error) {
            console.error('Error fetching SLA Data:', error);
            this.timeLeftText = 'Error';
            this.clearIntervals();
        }
    }

    formatDate(ms) {
        const d = new Date(ms);
        return new Intl.DateTimeFormat('en-US', {
            day: '2-digit', month: 'short', year: 'numeric',
            hour: '2-digit', minute: '2-digit', hour12: true
        }).format(d).replace(',', '');
    }

    startTimer() {
        this.clearIntervals();
        this.updateTimeLeft();
        
        this.timer = setInterval(() => {
            this.updateTimeLeft();
        }, 1000);
    }

    updateTimeLeft() {
        if (!this.deadline || !this.startDate || this.isFullyBreached) return;

        const now = new Date().getTime();
        const totalDuration = this.deadline - this.startDate;
        let timeRemaining = this.deadline - now;

        if (timeRemaining <= 0) {
            timeRemaining = 0;
            this.clearIntervals();
            this.timeLeftText = '0 Mins';
            this.percentage = 0;
            this.slaStatusText = 'Breached';
            this.circleColor = '#ba0517'; // Red
            this.statusColorClass = 'status-red';
            return;
        }

        // Calculate percentage (Time Remaining / Total Duration)
        let calcPerc = (timeRemaining / totalDuration) * 100;
        if (calcPerc > 100) calcPerc = 100;
        if (calcPerc < 0) calcPerc = 0;
        
        this.percentage = Math.round(calcPerc);

        // Calculate hours and minutes for center text
        const hours = Math.floor(timeRemaining / (1000 * 60 * 60));
        if (hours > 0) {
            this.timeLeftText = `${hours} Hours`;
        } else {
            const minutes = Math.ceil(timeRemaining / (1000 * 60));
            this.timeLeftText = `${minutes} Min${minutes === 1 ? '' : 's'}`;
        }

        // Exact countdown timer for below the chart
        const m = Math.floor(timeRemaining / (1000 * 60)) % 60;
        const s = Math.floor(timeRemaining / 1000) % 60;
        this.countdownTimer = `${hours}h ${m}m ${s}s`;

        // Color Logic based on User Request
        // 100-50% Green, 50-25% Yellow, <25% Red
        if (this.percentage > 50) {
            this.circleColor = '#4bca81';
            this.slaStatusText = 'Safe';
            this.statusColorClass = 'status-green';
        } else if (this.percentage > 25 && this.percentage <= 50) {
            this.circleColor = '#ffb75d';
            this.slaStatusText = 'Warning';
            this.statusColorClass = 'status-yellow';
        } else {
            this.circleColor = '#ba0517';
            this.slaStatusText = 'Critical';
            this.statusColorClass = 'status-red';
        }
    }

    get textColorStyle() {
        return `color: ${this.circleColor};`;
    }

    get statusBadgeClass() {
        return `status-badge ${this.statusColorClass}`;
    }

    // Dynamic SVG styling
    get circleDasharray() {
        return '282.74';
    }
    
    get circleDashoffset() {
        const circumference = 282.74;
        const offset = circumference - ((this.percentage / 100) * circumference);
        return offset;
    }

    clearIntervals() {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = undefined;
        }
    }

    disconnectedCallback() {
        this.clearIntervals();
    }
}