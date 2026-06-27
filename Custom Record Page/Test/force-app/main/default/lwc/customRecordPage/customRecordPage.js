import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveLayout from '@salesforce/apex/LayoutManagerService.getActiveLayout';

export default class CustomRecordPage extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api backgroundImageUrl;
    @api displayedFields; // Kept for backwards compatibility with active flexipages
    @api layoutConfigJSON; // Manual override

    @track parsedLayout = null;

    get backgroundStyle() {
        // Prioritize JSON config over manual property
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
        // If manual config is provided via App Builder, it overrides the database.
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
                    
                    let subsections = [];
                    if (section.subsections) {
                        subsections = section.subsections.map(sub => {
                            const subCols = parseInt(sub.columns || 2, 10);
                            let subSize = 'slds-size_1-of-2';
                            if (subCols === 1) subSize = 'slds-size_1-of-1';
                            else if (subCols === 3) subSize = 'slds-size_1-of-3';
                            else if (subCols === 4) subSize = 'slds-size_1-of-4';
                            return {
                                ...sub,
                                columnClass: `slds-col ${subSize} slds-p-horizontal_small slds-m-bottom_small`
                            };
                        });
                    }
                    
                    return {
                        ...section,
                        columnClass: `slds-col ${colSize} slds-p-horizontal_small slds-m-bottom_small`,
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
