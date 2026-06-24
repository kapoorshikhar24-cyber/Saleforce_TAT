import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadFields from '@salesforce/apex/LeadScoringController.getLeadFields';
import getScoringRules from '@salesforce/apex/LeadScoringController.getScoringRules';
import saveRule from '@salesforce/apex/LeadScoringController.saveRule';
import deleteRule from '@salesforce/apex/LeadScoringController.deleteRule';
import recalculateAllLeads from '@salesforce/apex/LeadScoringController.recalculateAllLeads';

export default class LeadScoringAdmin extends LightningElement {
    @track fields = [];
    @track rules = [];
    @track isLoading = false;
    @track isRecalculating = false;

    // Form inputs
    @track selectedField = '';
    @track selectedOperator = 'Equals';
    @track selectedValue = '';
    @track selectedScore = 0;

    // Field descriptions mapped by API Name
    fieldMap = {};

    operatorOptions = [
        { label: 'Equals', value: 'Equals' },
        { label: 'Not Equals', value: 'Not_Equals' },
        { label: 'Greater Than', value: 'Greater_Than' },
        { label: 'Less Than', value: 'Less_Than' },
        { label: 'Contains', value: 'Contains' }
    ];

    booleanOptions = [
        { label: 'True', value: 'true' },
        { label: 'False', value: 'false' }
    ];

    @wire(getLeadFields)
    wiredFields({ error, data }) {
        if (data) {
            this.fields = data;
            this.fieldMap = {};
            data.forEach(f => {
                this.fieldMap[f.apiName] = f;
            });
        } else if (error) {
            this.showToast('Error loading fields', error.body?.message || 'Unknown error', 'error');
        }
    }

    connectedCallback() {
        this.loadRules();
    }

    loadRules() {
        this.isLoading = true;
        getScoringRules()
            .then(result => {
                this.rules = result.map(rule => {
                    let scoreClass = 'score-positive';
                    if (rule.Score__c < 0) {
                        scoreClass = 'score-negative';
                    } else if (rule.Score__c === 0) {
                        scoreClass = 'score-neutral';
                    }
                    return {
                        ...rule,
                        scoreClass: scoreClass
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error loading rules', error.body?.message || 'Unknown error', 'error');
            });
    }

    get fieldOptions() {
        return this.fields.map(f => ({
            label: `${f.label} (${f.apiName})`,
            value: f.apiName
        }));
    }

    get currentField() {
        return this.fieldMap[this.selectedField];
    }

    get isPicklistField() {
        return this.currentField?.type === 'PICKLIST';
    }

    get isBooleanField() {
        return this.currentField?.type === 'BOOLEAN';
    }

    get isNumberField() {
        const type = this.currentField?.type;
        return type === 'INTEGER' || type === 'DOUBLE' || type === 'CURRENCY' || type === 'PERCENT';
    }

    get isTextField() {
        return !this.isPicklistField && !this.isBooleanField && !this.isNumberField && this.selectedField !== '';
    }

    get picklistValueOptions() {
        if (this.isPicklistField && this.currentField.picklistValues) {
            return this.currentField.picklistValues.map(v => ({ label: v, value: v }));
        }
        return [];
    }

    get rulesCount() {
        return this.rules.length;
    }

    get hasRules() {
        return this.rules.length > 0;
    }

    get isFormInvalid() {
        return !this.selectedField || !this.selectedOperator || this.selectedValue === '' || this.selectedValue === undefined;
    }

    handleFieldChange(event) {
        this.selectedField = event.target.value;
        this.selectedValue = ''; // reset value on field change
    }

    handleOperatorChange(event) {
        this.selectedOperator = event.target.value;
    }

    handleValueChange(event) {
        this.selectedValue = event.target.value;
    }

    handleScoreChange(event) {
        this.selectedScore = parseInt(event.target.value, 10) || 0;
    }

    handleAddRule() {
        if (this.isFormInvalid) {
            this.showToast('Missing Fields', 'Please fill in all required inputs.', 'warning');
            return;
        }

        const fieldDesc = this.currentField;
        const ruleRecord = {
            sobjectType: 'Lead_Scoring_Rule__c',
            Field_Api_Name__c: this.selectedField,
            Field_Label__c: fieldDesc.label,
            Operator__c: this.selectedOperator,
            Value__c: String(this.selectedValue),
            Score__c: this.selectedScore
        };

        this.isLoading = true;
        saveRule({ rule: ruleRecord })
            .then(() => {
                this.showToast('Success', 'Rule created successfully.', 'success');
                this.selectedValue = '';
                this.selectedScore = 0;
                this.loadRules();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error saving rule', error.body?.message || 'Unknown error', 'error');
            });
    }

    handleDeleteRule(event) {
        const ruleId = event.target.dataset.id;
        this.isLoading = true;
        deleteRule({ ruleId })
            .then(() => {
                this.showToast('Success', 'Rule deleted.', 'success');
                this.loadRules();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error deleting rule', error.body?.message || 'Unknown error', 'error');
            });
    }

    handleRecalculateAll() {
        this.isRecalculating = true;
        recalculateAllLeads()
            .then(message => {
                this.showToast('Recalculation Started', message, 'info');
                this.isRecalculating = false;
            })
            .catch(error => {
                this.isRecalculating = false;
                this.showToast('Error starting recalculation', error.body?.message || 'Unknown error', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
