import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SortableJS from '@salesforce/resourceUrl/SortableJS';
import getAllObjects from '@salesforce/apex/SchemaService.getAllObjects';
import getObjectFields from '@salesforce/apex/SchemaService.getObjectFields';
import saveLayout from '@salesforce/apex/LayoutManagerService.saveLayout';

export default class DynamicLayoutBuilder extends LightningElement {
    @track selectedObject = '';
    @track objectOptions = [];
    @track fields = [];
    
    @track layoutConfiguration = {
        backgroundImageUrl: '',
        sections: [
            { id: 'section_1', name: 'Information', columns: 2, fields: [] }
        ]
    };

    @track selectedNode = null; // { type: 'section' | 'field', sectionId: '..', apiName: '..' }

    sortableInitialized = false;
    sortableInstances = [];

    @wire(getAllObjects)
    wiredObjects({ error, data }) {
        if (data) {
            this.objectOptions = [...data].sort((a, b) => a.label.localeCompare(b.label));
        }
    }

    @wire(getObjectFields, { objectApiName: '$selectedObject' })
    wiredFields({ error, data }) {
        if (data) {
            this.fields = [...data].sort((a, b) => a.label.localeCompare(b.label));
            setTimeout(() => this.initializeSortable(), 100);
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
    }

    renderedCallback() {
        if (this.sortableInitialized) return;
        Promise.all([loadScript(this, SortableJS)])
        .then(() => {
            this.sortableInitialized = true;
            this.initializeSortable();
        }).catch(err => console.error(err));
    }

    initializeSortable() {
        if (!this.sortableInitialized) return;

        this.sortableInstances.forEach(instance => instance.destroy());
        this.sortableInstances = [];

        const fieldListEl = this.template.querySelector('.field-list-ul');
        if (fieldListEl) {
            const listInstance = window.Sortable.create(fieldListEl, {
                group: { name: 'shared', pull: 'clone', put: false },
                sort: false, animation: 150
            });
            this.sortableInstances.push(listInstance);
        }

        const sectionEls = this.template.querySelectorAll('.canvas-section-fields');
        sectionEls.forEach(sectionEl => {
            const sectionInstance = window.Sortable.create(sectionEl, {
                group: 'shared', animation: 150,
                onAdd: (evt) => this.handleDrop(evt),
                onUpdate: (evt) => this.handleUpdate(evt)
            });
            this.sortableInstances.push(sectionInstance);
        });
    }

    handleDrop(evt) {
        evt.item.parentNode.removeChild(evt.item);
        const fieldApiName = evt.item.dataset.apiname;
        const sectionId = evt.to.dataset.sectionid;
        
        const fieldData = this.fields.find(f => f.apiName === fieldApiName);
        if (!fieldData) return;
        
        // Clone field data so we can modify properties per instance
        const fieldInstance = { ...fieldData, required: fieldData.isRequired, readOnly: !fieldData.isUpdateable };

        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let section = sections.find(s => s.id === sectionId);
        if (section) {
            section.fields.splice(evt.newIndex, 0, fieldInstance);
            this.layoutConfiguration.sections = sections;
        }
    }

    handleUpdate(evt) {
        const sectionId = evt.to.dataset.sectionid;
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let section = sections.find(s => s.id === sectionId);
        if (section) {
            const item = section.fields.splice(evt.oldIndex, 1)[0];
            section.fields.splice(evt.newIndex, 0, item);
            this.layoutConfiguration.sections = sections;
        }
    }

    // --- Property Selection & Editing ---

    handleSectionClick(event) {
        // Stop propagation so it doesn't trigger canvas click
        event.stopPropagation();
        const sectionId = event.currentTarget.dataset.sectionid;
        this.selectedNode = { type: 'section', sectionId: sectionId };
    }

    handleFieldClick(event) {
        event.stopPropagation();
        const sectionId = event.currentTarget.dataset.sectionid;
        const apiName = event.currentTarget.dataset.apiname;
        this.selectedNode = { type: 'field', sectionId: sectionId, apiName: apiName };
    }

    handleCanvasClick() {
        this.selectedNode = null; // Deselect
    }

    get isSectionSelected() {
        return this.selectedNode && this.selectedNode.type === 'section';
    }

    get isFieldSelected() {
        return this.selectedNode && this.selectedNode.type === 'field';
    }

    get isLayoutSelected() {
        return !this.selectedNode;
    }

    get selectedSectionData() {
        if (!this.isSectionSelected) return null;
        return this.layoutConfiguration.sections.find(s => s.id === this.selectedNode.sectionId);
    }

    get selectedFieldData() {
        if (!this.isFieldSelected) return null;
        const section = this.layoutConfiguration.sections.find(s => s.id === this.selectedNode.sectionId);
        return section.fields.find(f => f.apiName === this.selectedNode.apiName);
    }

    handleBackgroundImageChange(event) {
        this.layoutConfiguration.backgroundImageUrl = event.target.value;
    }

    handleSectionNameChange(event) {
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let section = sections.find(s => s.id === this.selectedNode.sectionId);
        section.name = event.target.value;
        this.layoutConfiguration.sections = sections;
    }

    handleFieldRequiredChange(event) {
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let section = sections.find(s => s.id === this.selectedNode.sectionId);
        let field = section.fields.find(f => f.apiName === this.selectedNode.apiName);
        field.required = event.target.checked;
        this.layoutConfiguration.sections = sections;
    }

    handleFieldReadOnlyChange(event) {
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let section = sections.find(s => s.id === this.selectedNode.sectionId);
        let field = section.fields.find(f => f.apiName === this.selectedNode.apiName);
        field.readOnly = event.target.checked;
        this.layoutConfiguration.sections = sections;
    }

    handleSaveDraft() {
        this.saveLayoutData('Draft');
    }

    handlePublish() {
        this.saveLayoutData('Published');
    }

    saveLayoutData(status) {
        if (!this.selectedObject) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Please select an object first.', variant: 'error' }));
            return;
        }

        const jsonString = JSON.stringify(this.layoutConfiguration);
        saveLayout({ objectApiName: this.selectedObject, layoutJson: jsonString, status: status })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: `Layout ${status} successfully!`, variant: 'success' }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error saving layout', message: error.body ? error.body.message : error.message, variant: 'error' }));
            });
    }
}
