import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadScoreDetails from '@salesforce/apex/LeadScoringController.getLeadScoreDetails';

export default class LeadScoreCard extends LightningElement {
    @api recordId;
    @track totalScore = 0;
    @track matches = [];
    @track isLoading = true;

    radius = 45;
    circumference = 2 * Math.PI * 45; // ~282.74

    connectedCallback() {
        this.loadLeadScore();
    }

    loadLeadScore() {
        this.isLoading = true;
        getLeadScoreDetails({ leadId: this.recordId })
            .then(result => {
                this.totalScore = result.totalScore;
                this.matches = result.matches.map(m => {
                    let scoreClass = 'points-positive';
                    let formattedScore = `+${m.score}`;
                    if (m.score < 0) {
                        scoreClass = 'points-negative';
                        formattedScore = `${m.score}`;
                    } else if (m.score === 0) {
                        scoreClass = 'points-neutral';
                        formattedScore = '0';
                    }

                    let opLabel = '=';
                    if (m.operator === 'Not_Equals') opLabel = '!=';
                    else if (m.operator === 'Greater_Than') opLabel = '>';
                    else if (m.operator === 'Less_Than') opLabel = '<';
                    else if (m.operator === 'Contains') opLabel = 'contains';

                    return {
                        ...m,
                        scoreClass,
                        formattedScore,
                        operatorLabel: opLabel
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error evaluating Lead', error.body?.message || 'Unknown error', 'error');
            });
    }

    handleRefresh() {
        this.loadLeadScore();
    }

    get strokeDashoffset() {
        let visualScore = this.totalScore;
        if (visualScore > 100) visualScore = 100;
        if (visualScore < 0) visualScore = 0;
        
        return this.circumference - (visualScore / 100) * this.circumference;
    }

    get leadGrade() {
        if (this.totalScore >= 70) return 'Hot Lead';
        if (this.totalScore >= 35) return 'Warm Lead';
        return 'Cold Lead';
    }

    get gradeDescription() {
        if (this.totalScore >= 70) return 'High engagement and high-quality profile. Priority contact.';
        if (this.totalScore >= 35) return 'Moderate matching signals. Nurture and monitor.';
        return 'Low matching scores. Requires qualification or review.';
    }

    get badgeClass() {
        if (this.totalScore >= 70) return 'badge badge-hot';
        if (this.totalScore >= 35) return 'badge badge-warm';
        return 'badge badge-cold';
    }

    get gradientStartColor() {
        if (this.totalScore >= 70) return '#34d399'; // Emerald-400
        if (this.totalScore >= 35) return '#fbbf24'; // Amber-400
        return '#f87171'; // Red-400
    }

    get gradientEndColor() {
        if (this.totalScore >= 70) return '#059669'; // Emerald-600
        if (this.totalScore >= 35) return '#d97706'; // Amber-600
        return '#e11d48'; // Rose-600
    }

    get hasMatches() {
        return this.matches.length > 0;
    }

    get matchCount() {
        return this.matches.length;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
