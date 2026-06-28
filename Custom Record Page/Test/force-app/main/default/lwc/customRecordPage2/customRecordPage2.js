import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveLayout from '@salesforce/apex/LayoutManagerService.getActiveLayout';

export default class CustomRecordPage2 extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api backgroundImageUrl;
    @api displayedFields; 
    @api layoutConfigJSON; 

    @track parsedLayout = null;

    get backgroundStyle() {
        let bgUrl = this.backgroundImageUrl;
        if (this.parsedLayout && this.parsedLayout.backgroundImageUrl) {
            bgUrl = this.parsedLayout.backgroundImageUrl;
        }

        if (bgUrl) {
            return `background-image: url('${bgUrl}'); background-size: cover; background-position: center;`;
        }
        return '';
    }

    @wire(getActiveLayout, { objectApiName: '$objectApiName' })
    wiredLayout({ error, data }) {
        if (this.layoutConfigJSON) {
            this.parseConfig(this.layoutConfigJSON);
        } else if (data) {
            this.parseConfig(data);
        } else if (error) {
            console.error('Error fetching layout', error);
        }
    }

    handleSuccess(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Record updated successfully!',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error saving record',
                message: event.detail ? event.detail.message : 'Error saving record.',
                variant: 'error'
            })
        );
    }

    parseConfig(jsonString) {
        try {
            const raw = JSON.parse(jsonString);
            if (raw && raw.sections) {
                raw.sections = raw.sections.map(section => {
                    const columns = parseInt(section.columns || 2, 10);
                    let colSize = 'slds-size_1-of-2';
                    if (columns === 1) colSize = 'slds-size_1-of-1';
                    else if (columns === 3) colSize = 'slds-size_1-of-3';
                    else if (columns === 4) colSize = 'slds-size_1-of-4';
                    else if (columns === 6) colSize = 'slds-size_1-of-6';
                    
                    const w = parseInt(section.width || 12, 10);
                    let widthSize = 'slds-size_1-of-1';
                    if (w === 6) widthSize = 'slds-size_1-of-2';
                    else if (w === 4) widthSize = 'slds-size_1-of-3';
                    else if (w === 3) widthSize = 'slds-size_1-of-4';
                    
                    let containerClass = 'slds-section__content slds-grid slds-wrap';
                    if (section.horizontalScroll) {
                        containerClass = 'slds-section__content slds-grid scrollable-fields-container';
                    }
                    
                    let subsections = [];
                    if (section.subsections) {
                        subsections = section.subsections.map(sub => {
                            const subCols = parseInt(sub.columns || 2, 10);
                            let subSize = 'slds-size_1-of-2';
                            if (subCols === 1) subSize = 'slds-size_1-of-1';
                            else if (subCols === 3) subSize = 'slds-size_1-of-3';
                            else if (subCols === 4) subSize = 'slds-size_1-of-4';
                            else if (subCols === 6) subSize = 'slds-size_1-of-6';
                            
                            let subContainerClass = 'slds-section__content slds-grid slds-wrap';
                            if (sub.horizontalScroll) {
                                subContainerClass = 'slds-section__content slds-grid scrollable-fields-container';
                            }
                            
                            return {
                                ...sub,
                                columnClass: `slds-col ${subSize} slds-p-horizontal_small slds-m-bottom_small`,
                                fieldsContainerClass: subContainerClass
                            };
                        });
                    }
                    
                    return {
                        ...section,
                        columnClass: `slds-col ${colSize} slds-p-horizontal_small slds-m-bottom_small`,
                        widthClass: `slds-col ${widthSize} slds-p-horizontal_small slds-m-bottom_medium`,
                        fieldsContainerClass: containerClass,
                        subsections
                    };
                });
            }
            this.parsedLayout = raw;
        } catch (e) {
            console.error('Invalid Layout JSON', e);
        }
    }

    get hasLayout() {
        return this.parsedLayout && this.parsedLayout.sections && this.parsedLayout.sections.length > 0;
    }
}
