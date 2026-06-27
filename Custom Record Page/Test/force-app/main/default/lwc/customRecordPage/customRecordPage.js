import { LightningElement, api, wire, track } from 'lwc';
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

    parseConfig(jsonString) {
        try {
            this.parsedLayout = JSON.parse(jsonString);
        } catch (e) {
            console.error('Invalid Layout JSON', e);
        }
    }

    get hasLayout() {
        return this.parsedLayout && this.parsedLayout.sections && this.parsedLayout.sections.length > 0;
    }
}
