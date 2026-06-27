# Dynamic Record Layout Builder & Render Engine

A zero-code drag-and-drop Dynamic Record Layout Builder for Salesforce. This solution enables Administrators to build custom layouts (with custom sections, fields, and styling properties like background images) and automatically render them on record pages dynamically.

---

## 🛠️ Architecture & Core Components

The solution consists of four primary technical components:

1. **`SchemaService` (Apex Class)**: Handles backend schema introspection. It dynamically fetches all available Salesforce objects in the org and retrieves their fields (including labels, API names, type, whether they are required, and editability).
2. **`LayoutManagerService` (Apex Class)**: Handles database persistence for layout configuration. It saves draft or published layouts and retrieves the active published layout JSON for the rendering engine.
3. **`dynamicLayoutBuilder` (LWC - Admin Tool)**: The visual, drag-and-drop designer interface where Admins choose an object, drag fields into custom sections, configure field properties (Required / Read-Only), set background images, and publish layouts.
4. **`customRecordPage` (LWC - End-User Engine)**: The runtime render engine. It automatically retrieves the published layout JSON from the database and uses `lightning-record-edit-form` to render the custom form layout directly on the record detail page.

---

## 🗄️ Database Schema (Custom Metadata Storage)

The configurations are saved in two custom objects deployed to your Salesforce org:

### 1. Dynamic Layout (`Dynamic_Layout__c`)
Stores layout metadata at the object level.
* **`Object_API_Name__c`** (Text 255 - Required): The API name of the Salesforce object this layout applies to (e.g., `Account`, `Contact`).
* **`Status__c`** (Picklist): The state of the layout (`Draft` or `Published`).
* **`Background_Image_URL__c`** (URL): The URL of the background image configured for this layout.
* **`Displayed_Fields__c`** (Long Text Area): Comma-separated list of all fields positioned in the layout (useful for reporting or backend queries).
* **`Layout_Config_JSON__c`** (Long Text Area): The full JSON representation of the layout structure, containing columns, sections, fields, and properties.

### 2. Layout Version (`Layout_Version__c`)
A child object (Master-Detail) of `Dynamic_Layout__c` to keep history/backups of all saved drafts and publishes.
* **`Dynamic_Layout__c`** (Master-Detail): Pointer to the parent layout.
* **`Version_Number__c`** (Number): Increments automatically on every save.
* **`Configuration_JSON__c`** (Long Text Area): Stores the layout JSON snapshot for that version.

---

## 🚀 Admin Setup & User Guide

### Step 1: Design and Publish a Layout
1. Open setup and go to **Lightning App Builder**. Create a new **App Page** (e.g., "Layout Builder") and add the **Dynamic Record Layout Builder** component onto the page. Save and activate it.
2. Open the newly created App Page.
3. Use the combobox to **select a Salesforce Object** (e.g., `Account`).
4. Click on the gray background canvas to open **Layout Configuration** in the Right Sidebar and paste a **Background Image URL** (optional).
5. Drag and drop fields from the left-hand field list onto the section in the center canvas.
6. Click any section header or field to modify properties in the Right Sidebar (e.g., Rename sections, make fields **Required** or **Read Only**).
7. Click **Publish** at the top right to save and activate the layout!

### Step 2: Render the Layout on Record Pages
1. Go to any record page of the object you chose (e.g., an Account detail page).
2. Click the gear icon at the top right > **Edit Page** to open the Lightning App Builder.
3. Drag the **Custom Record Page** custom component onto the page.
4. Save and activate the record page.
5. Navigate back to the record. The component will automatically fetch the published configuration for the object and render your custom layout with the sections, fields, validations, and background image you configured!

---

## ⚡ JSON Configuration Structure
Below is an example of the configuration JSON saved under `Layout_Config_JSON__c`:
```json
{
  "backgroundImageUrl": "https://example.com/background.jpg",
  "sections": [
    {
      "id": "section_1",
      "name": "General Details",
      "columns": 2,
      "fields": [
        {
          "apiName": "Name",
          "label": "Account Name",
          "required": true,
          "readOnly": false
        },
        {
          "apiName": "Phone",
          "label": "Phone",
          "required": false,
          "readOnly": true
        }
      ]
    }
  ]
}
```
