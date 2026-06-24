import { LightningElement, api, wire, track } from 'lwc';
import getScoreDetails from '@salesforce/apex/ScoringController.getScoreDetails';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class LeadScoreCard extends LightningElement {
    @api recordId;
    @api objectApiName;
    @track scoreData;
    @track error;
    @track isLoading = true;

    // SVG parameters for the dial
    circumference = 2 * Math.PI * 45; // 2 * pi * r
    
    get scoreDasharray() {
        if (!this.scoreData) return `0 ${this.circumference}`;
        // Map 0-100 score to circumference
        const normalizedScore = Math.max(0, Math.min(100, this.scoreData.totalScore));
        const fill = (normalizedScore / 100) * this.circumference;
        return `${fill} ${this.circumference}`;
    }
    
    get scoreColorClass() {
        if (!this.scoreData) return 'dial-path neutral';
        if (this.scoreData.totalScore >= 75) return 'dial-path hot';
        if (this.scoreData.totalScore >= 40) return 'dial-path warm';
        return 'dial-path cold';
    }

    get displayScore() {
        return this.scoreData ? this.scoreData.totalScore : 0;
    }

    get scoreLabel() {
        if (!this.scoreData) return 'Unscored';
        if (this.scoreData.totalScore >= 75) return 'Hot';
        if (this.scoreData.totalScore >= 40) return 'Warm';
        return 'Cold';
    }

    @wire(getScoreDetails, { recordId: '$recordId', objectApiName: '$objectApiName' })
    wiredScore(result) {
        this.isLoading = false;
        if (result.data) {
            // Process data for UI
            let processedMatches = result.data.matches.map(m => {
                let isPositive = m.score > 0;
                let sign = isPositive ? '+' : '';
                
                // Format the operator to be user-friendly
                let opLabel = '=';
                if (m.operator === 'Not_Equals') opLabel = '!=';
                else if (m.operator === 'Greater_Than') opLabel = '>';
                else if (m.operator === 'Less_Than') opLabel = '<';
                else if (m.operator === 'Contains') opLabel = 'contains';
                else if (m.operator === 'IsBlank') opLabel = 'is blank';
                else if (m.operator === 'IsNotBlank') opLabel = 'is not blank';

                return {
                    ...m,
                    scoreDisplay: `${sign}${m.score}`,
                    scoreClass: isPositive ? 'score-positive' : 'score-negative',
                    displayCriteria: `${m.fieldLabel} ${opLabel} ${m.configuredValue}`
                };
            });
            
            this.scoreData = {
                totalScore: result.data.totalScore,
                matches: processedMatches
            };
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.scoreData = undefined;
        }
    }

    refreshScore() {
        this.isLoading = true;
        // Trigger cache invalidation for this record
        getRecordNotifyChange([{ recordId: this.recordId }]);
        // Note: The wire will auto-refresh if the underlying record changes, 
        // but an imperative call is better if we want to force it. 
        // For simplicity, we just trigger the record notify change.
        setTimeout(() => {
            this.isLoading = false;
        }, 500);
    }
}
