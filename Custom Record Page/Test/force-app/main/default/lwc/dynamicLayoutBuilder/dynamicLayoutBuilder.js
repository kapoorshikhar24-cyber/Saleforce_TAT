import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SortableJS from '@salesforce/resourceUrl/SortableJS';
import getAllObjects from '@salesforce/apex/SchemaService.getAllObjects';
import getObjectFields from '@salesforce/apex/SchemaService.getObjectFields';
import saveLayout from '@salesforce/apex/LayoutManagerService.saveLayout';
import getOrCreateLayout from '@salesforce/apex/LayoutManagerService.getOrCreateLayout';
import getUploadedImageUrl from '@salesforce/apex/LayoutManagerService.getUploadedImageUrl';

export default class DynamicLayoutBuilder extends LightningElement {
    @track selectedObject = '';
    @track objectOptions = [];
    @track fields = [];
    @track layoutRecordId = '';
    
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
        } else if (error) {
            console.error('Error fetching objects:', error);
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
        this.layoutRecordId = '';
        this.selectedNode = null;
        
        getOrCreateLayout({ objectApiName: this.selectedObject })
            .then(data => {
                this.layoutRecordId = data.recordId;
                if (data.layoutConfigJson) {
                    try {
                        this.layoutConfiguration = JSON.parse(data.layoutConfigJson);
                    } catch (e) {
                        console.error('Error parsing loaded layout JSON', e);
                    }
                } else {
                    // Reset to default template if no layout exists
                    this.layoutConfiguration = {
                        backgroundImageUrl: data.backgroundImageUrl || '',
                        sections: [
                            { id: 'section_1', name: 'Information', columns: 2, fields: [] }
                        ]
                    };
                }
                setTimeout(() => this.initializeSortable(), 100);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error loading layout', message: error.body ? error.body.message : error.message, variant: 'error' }));
            });
    }

    renderedCallback() {
        if (this.sortableInitialized) return;
        Promise.all([loadScript(this, SortableJS)])
        .then(() => {
            this.sortableInitialized = true;
            this.initializeSortable();
        }).catch(err => console.error(err));
    }

    handleSidebarClick(event) {
        event.stopPropagation();
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

        // Initialize top-level sections reordering
        const sectionsEl = this.template.querySelector('.canvas-sections-list');
        if (sectionsEl) {
            const sectionsInstance = window.Sortable.create(sectionsEl, {
                animation: 150,
                handle: '.slds-section__title',
                onEnd: (evt) => {
                    let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
                    const item = sections.splice(evt.oldIndex, 1)[0];
                    sections.splice(evt.newIndex, 0, item);
                    this.layoutConfiguration.sections = sections;
                }
            });
            this.sortableInstances.push(sectionsInstance);
        }
    }

    findSectionById(sections, id) {
        for (let sec of sections) {
            if (sec.id === id) return sec;
            if (sec.subsections) {
                let sub = sec.subsections.find(s => s.id === id);
                if (sub) return sub;
            }
        }
        return null;
    }

    handleDrop(evt) {
        evt.item.parentNode.removeChild(evt.item);
        const fieldApiName = evt.item.dataset.apiname;
        const sectionId = evt.to.dataset.sectionid;
        
        const fieldData = this.fields.find(f => f.apiName === fieldApiName);
        if (!fieldData) return;
        
        const fieldInstance = { ...fieldData, required: fieldData.isRequired, readOnly: !fieldData.isUpdateable };

        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let section = this.findSectionById(sections, sectionId);
        if (section) {
            section.fields.splice(evt.newIndex, 0, fieldInstance);
            this.layoutConfiguration.sections = sections;
        }
    }

    handleUpdate(evt) {
        const sectionId = evt.to.dataset.sectionid;
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let section = this.findSectionById(sections, sectionId);
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
        return this.selectedNode && (this.selectedNode.type === 'section' || this.selectedNode.type === 'subsection');
    }

    get isTopLevelSectionSelected() {
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
        if (this.selectedNode.type === 'section') {
            return this.layoutConfiguration.sections.find(s => s.id === this.selectedNode.sectionId);
        } else {
            let parent = this.layoutConfiguration.sections.find(s => s.id === this.selectedNode.parentSectionId);
            return parent && parent.subsections ? parent.subsections.find(sub => sub.id === this.selectedNode.sectionId) : null;
        }
    }

    get selectedSectionName() {
        const data = this.selectedSectionData;
        return data ? data.name : '';
    }

    get selectedSectionColumns() {
        const data = this.selectedSectionData;
        return data ? data.columns : 2;
    }

    get selectedFieldData() {
        if (!this.isFieldSelected) return null;
        for (let sec of this.layoutConfiguration.sections) {
            let field = sec.fields.find(f => f.apiName === this.selectedNode.apiName);
            if (field) return field;
            if (sec.subsections) {
                for (let sub of sec.subsections) {
                    let subField = sub.fields.find(f => f.apiName === this.selectedNode.apiName);
                    if (subField) return subField;
                }
            }
        }
        return null;
    }

    handleSubsectionClick(event) {
        event.stopPropagation();
        const subId = event.currentTarget.dataset.subid;
        const parentId = event.currentTarget.dataset.parentid;
        this.selectedNode = { type: 'subsection', sectionId: subId, parentSectionId: parentId };
    }

    get selectedFieldLabel() {
        const data = this.selectedFieldData;
        return data ? data.label : '';
    }

    get selectedFieldRequired() {
        const data = this.selectedFieldData;
        return data ? data.required : false;
    }

    get selectedFieldReadOnly() {
        const data = this.selectedFieldData;
        return data ? data.readOnly : false;
    }

    get renderedSections() {
        return this.layoutConfiguration.sections.map(section => {
            const cols = parseInt(section.columns || 2, 10);
            let sizeClass = 'slds-size_1-of-2';
            if (cols === 1) sizeClass = 'slds-size_1-of-1';
            else if (cols === 3) sizeClass = 'slds-size_1-of-3';
            else if (cols === 4) sizeClass = 'slds-size_1-of-4';
            else if (cols === 6) sizeClass = 'slds-size_1-of-6';
            
            const w = parseInt(section.width || 12, 10);
            let widthSize = 'slds-size_1-of-1';
            if (w === 6) widthSize = 'slds-size_1-of-2';
            else if (w === 4) widthSize = 'slds-size_1-of-3';
            else if (w === 3) widthSize = 'slds-size_1-of-4';
            
            let subsections = [];
            if (section.subsections) {
                subsections = section.subsections.map(sub => {
                    const subCols = parseInt(sub.columns || 2, 10);
                    let subSize = 'slds-size_1-of-2';
                    if (subCols === 1) subSize = 'slds-size_1-of-1';
                    else if (subCols === 3) subSize = 'slds-size_1-of-3';
                    else if (subCols === 4) subSize = 'slds-size_1-of-4';
                    else if (subCols === 6) subSize = 'slds-size_1-of-6';
                    
                    let subContainerClass = 'canvas-section-fields slds-grid slds-wrap';
                    if (sub.horizontalScroll) {
                        subContainerClass = 'canvas-section-fields slds-grid scrollable-fields-container';
                    }
                    
                    return {
                        ...sub,
                        fieldClass: `slds-col ${subSize} slds-p-around_x-small`,
                        fieldsContainerClass: subContainerClass
                    };
                });
            }
            
            let containerClass = 'canvas-section-fields slds-grid slds-wrap';
            if (section.horizontalScroll) {
                containerClass = 'canvas-section-fields slds-grid scrollable-fields-container';
            }
            
            return {
                ...section,
                fieldClass: `slds-col ${sizeClass} slds-p-around_x-small`,
                widthClass: `slds-col ${widthSize} slds-p-horizontal_small slds-m-bottom_medium`,
                fieldsContainerClass: containerClass,
                subsections
            };
        });
    }

    get columnOptions() {
        return [
            { label: '1 Column', value: 1 },
            { label: '2 Columns', value: 2 },
            { label: '3 Columns', value: 3 },
            { label: '4 Columns', value: 4 },
            { label: '6 Columns', value: 6 }
        ];
    }

    get widthOptions() {
        return [
            { label: '100% (Full Width)', value: 12 },
            { label: '50% (Half Width)', value: 6 },
            { label: '33% (1/3 Width)', value: 4 },
            { label: '25% (1/4 Width)', value: 3 }
        ];
    }

    get selectedSectionWidth() {
        const data = this.selectedSectionData;
        return data ? (data.width || 12) : 12;
    }

    get selectedSectionScroll() {
        const data = this.selectedSectionData;
        return data ? !!data.horizontalScroll : false;
    }

    handleAddSection(event) {
        event.stopPropagation();
        const nextId = `section_${Date.now()}`;
        const newSection = {
            id: nextId,
            name: `New Section ${this.layoutConfiguration.sections.length + 1}`,
            columns: 2,
            width: 12,
            horizontalScroll: false,
            fields: [],
            subsections: []
        };
        this.layoutConfiguration.sections = [...this.layoutConfiguration.sections, newSection];
        setTimeout(() => this.initializeSortable(), 100);
    }

    handleAddSubsection(event) {
        event.stopPropagation();
        if (!this.selectedNode || this.selectedNode.type !== 'section') return;
        const parentId = this.selectedNode.sectionId;
        
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        let parent = sections.find(s => s.id === parentId);
        if (parent) {
            if (!parent.subsections) parent.subsections = [];
            const nextSubId = `sub_${Date.now()}`;
            parent.subsections.push({
                id: nextSubId,
                name: `Subsection ${parent.subsections.length + 1}`,
                columns: 2,
                fields: []
            });
            this.layoutConfiguration.sections = sections;
            setTimeout(() => this.initializeSortable(), 100);
        }
    }

    handleDeleteSection(event) {
        event.stopPropagation();
        if (!this.selectedNode) return;
        
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        if (this.selectedNode.type === 'section') {
            const sectionId = this.selectedNode.sectionId;
            sections = sections.filter(s => s.id !== sectionId);
        } else if (this.selectedNode.type === 'subsection') {
            const parentId = this.selectedNode.parentSectionId;
            const subId = this.selectedNode.sectionId;
            let parent = sections.find(s => s.id === parentId);
            if (parent && parent.subsections) {
                parent.subsections = parent.subsections.filter(sub => sub.id !== subId);
            }
        }
        
        this.layoutConfiguration.sections = sections;
        this.selectedNode = null; // Deselect
        setTimeout(() => this.initializeSortable(), 100);
    }

    handleSectionColumnsChange(event) {
        const cols = parseInt(event.detail.value, 10);
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        if (this.selectedNode.type === 'section') {
            let section = sections.find(s => s.id === this.selectedNode.sectionId);
            if (section) section.columns = cols;
        } else if (this.selectedNode.type === 'subsection') {
            let parent = sections.find(s => s.id === this.selectedNode.parentSectionId);
            if (parent && parent.subsections) {
                let sub = parent.subsections.find(s => s.id === this.selectedNode.sectionId);
                if (sub) sub.columns = cols;
            }
        }
        this.layoutConfiguration.sections = sections;
    }

    handleSectionWidthChange(event) {
        const w = parseInt(event.detail.value, 10);
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        if (this.selectedNode.type === 'section') {
            let section = sections.find(s => s.id === this.selectedNode.sectionId);
            if (section) section.width = w;
        }
        this.layoutConfiguration.sections = sections;
    }

    handleSectionScrollChange(event) {
        const scroll = event.target.checked;
        let sections = JSON.parse(JSON.stringify(this.layoutConfiguration.sections));
        if (this.selectedNode.type === 'section') {
            let section = sections.find(s => s.id === this.selectedNode.sectionId);
            if (section) section.horizontalScroll = scroll;
        } else if (this.selectedNode.type === 'subsection') {
            let parent = sections.find(s => s.id === this.selectedNode.parentSectionId);
            if (parent && parent.subsections) {
                let sub = parent.subsections.find(s => s.id === this.selectedNode.sectionId);
                if (sub) sub.horizontalScroll = scroll;
            }
        }
        this.layoutConfiguration.sections = sections;
    }

    handleBackgroundImageChange(event) {
        this.layoutConfiguration.backgroundImageUrl = event.target.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            const docId = uploadedFiles[0].documentId;
            getUploadedImageUrl({ documentId: docId })
                .then(url => {
                    this.layoutConfiguration.backgroundImageUrl = url;
                    this.layoutConfiguration = { ...this.layoutConfiguration };
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Image uploaded and set as background successfully!',
                        variant: 'success'
                    }));
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error retrieving image',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    }));
                });
        }
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
