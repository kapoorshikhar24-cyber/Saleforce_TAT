import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getFields from '@salesforce/apex/ScoringController.getFields';
import getScoringRules from '@salesforce/apex/ScoringController.getScoringRules';
import saveRule from '@salesforce/apex/ScoringController.saveRule';
import deleteRule from '@salesforce/apex/ScoringController.deleteRule';
import triggerBatchRecalculation from '@salesforce/apex/ScoringController.triggerBatchRecalculation';

export default class LeadScoringAdmin extends LightningElement {
    @track rules = [];
    @track fieldOptions = [];
    
    @track selectedObject = 'Lead';
    objectOptions = [
        { label: 'Lead', value: 'Lead' },
        { label: 'Contact', value: 'Contact' },
        { label: 'Account', value: 'Account' },
        { label: 'Opportunity', value: 'Opportunity' }
    ];

    @track selectedField = '';
    @track selectedOperator = '';
    @track selectedValue = '';
    @track scoreValue = 0;
    
    fieldDataTypeMap = {};

    operatorOptions = [
        { label: 'Equals', value: 'Equals' },
        { label: 'Not Equals', value: 'Not_Equals' },
        { label: 'Greater Than', value: 'Greater_Than' },
        { label: 'Less Than', value: 'Less_Than' },
        { label: 'Contains', value: 'Contains' },
        { label: 'Is Blank', value: 'IsBlank' },
        { label: 'Is Not Blank', value: 'IsNotBlank' }
    ];

    booleanOptions = [
        { label: 'True', value: 'true' },
        { label: 'False', value: 'false' }
    ];

    isLoading = false;
    wiredRulesResult;

    @wire(getFields, { objectApiName: '$selectedObject' })
    wiredFields({ error, data }) {
        if (data) {
            this.fieldOptions = data.map(f => {
                this.fieldDataTypeMap[f.value] = f.type;
                return { label: f.label + ' (' + f.value + ')', value: f.value };
            });
        } else if (error) {
            this.showToast('Error loading fields', error.body.message, 'error');
        }
    }

    @wire(getScoringRules, { objectApiName: '$selectedObject' })
    wiredRules(result) {
        this.wiredRulesResult = result;
        if (result.data) {
            this.rules = result.data;
        } else if (result.error) {
            this.showToast('Error loading rules', result.error.body.message, 'error');
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.clearForm();
    }

    get selectedFieldType() {
        return this.fieldDataTypeMap[this.selectedField];
    }

    get isPicklistField() {
        return this.selectedFieldType === 'PICKLIST' || this.selectedFieldType === 'MULTIPICKLIST';
    }

    get isBooleanField() {
        return this.selectedFieldType === 'BOOLEAN';
    }

    get isNumberField() {
        return this.selectedFieldType === 'DOUBLE' || this.selectedFieldType === 'INTEGER' || this.selectedFieldType === 'CURRENCY' || this.selectedFieldType === 'PERCENT';
    }

    get isTextField() {
        return !this.isPicklistField && !this.isBooleanField && !this.isNumberField;
    }

    get showValueInput() {
        return this.selectedOperator !== 'IsBlank' && this.selectedOperator !== 'IsNotBlank';
    }

    get isFormInvalid() {
        if (!this.selectedField || !this.selectedOperator) return true;
        if (this.selectedOperator === 'IsBlank' || this.selectedOperator === 'IsNotBlank') return false;
        return this.selectedValue === '' || this.selectedValue === undefined;
    }

    handleFieldChange(event) {
        this.selectedField = event.detail.value;
        this.selectedValue = ''; // reset value on field change
        
        let selectFieldEl = this.template.querySelector('[data-id="fieldSelect"]');
        let selectedLabel = selectFieldEl.options.find(opt => opt.value === this.selectedField).label;
        this.selectedFieldLabel = selectedLabel.split(' (')[0]; 
    }

    handleOperatorChange(event) {
        this.selectedOperator = event.detail.value;
    }

    handleValueChange(event) {
        this.selectedValue = event.detail.value;
    }

    handleScoreChange(event) {
        this.scoreValue = event.detail.value;
    }

    saveRule() {
        if (this.isFormInvalid) {
            this.showToast('Validation Error', 'Please fill all required criteria fields.', 'warning');
            return;
        }

        this.isLoading = true;
        const newRule = {
            sobjectType: 'Lead_Scoring_Rule__c',
            Object_Api_Name__c: this.selectedObject,
            Field_Api_Name__c: this.selectedField,
            Field_Label__c: this.selectedFieldLabel,
            Operator__c: this.selectedOperator,
            Value__c: String(this.selectedValue),
            Score__c: this.scoreValue
        };

        saveRule({ rule: newRule })
            .then(() => {
                this.showToast('Success', 'Scoring rule saved successfully.', 'success');
                this.clearForm();
                return refreshApex(this.wiredRulesResult);
            })
            .catch(error => {
                this.showToast('Error saving rule', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    deleteRule(event) {
        const ruleId = event.target.dataset.id;
        this.isLoading = true;
        deleteRule({ ruleId: ruleId })
            .then(() => {
                this.showToast('Success', 'Rule deleted successfully.', 'success');
                return refreshApex(this.wiredRulesResult);
            })
            .catch(error => {
                this.showToast('Error deleting rule', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    runBatchRecalculation() {
        this.isLoading = true;
        triggerBatchRecalculation({ objectApiName: this.selectedObject })
            .then(() => {
                this.showToast('Batch Started', 'Recalculating scores for all ' + this.selectedObject + ' records in the background.', 'success');
            })
            .catch(error => {
                this.showToast('Error starting batch', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    clearForm() {
        this.selectedField = '';
        this.selectedOperator = '';
        this.selectedValue = '';
        this.scoreValue = 0;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
