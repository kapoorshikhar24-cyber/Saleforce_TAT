# Generic TAT (Turn Around Time) SLA Notification System

This repository contains a robust, highly configurable Turn Around Time (TAT) SLA system for Salesforce. It is designed to work on **any object**, dynamically respect **Business Hours** (including user-specific week-offs), and provide a live visual countdown timer to the user.

## System Architecture

The system relies on a hybrid architecture combining declarative Salesforce tools and Apex:

1. **Custom Metadata Type (`TAT_Configuration__mdt`)**: Acts as the rules engine. Admins define the SLA duration and applicable Business Hours per Object and Profile.
2. **Apex Calculation Engine (`TATSlaCalculator.cls`)**: An Invocable Method that reads the Custom Metadata and uses Salesforce's native `BusinessHours.add()` to calculate the exact deadline, automatically skipping weekends, nights, and specific days off.
3. **Record-Triggered Flow**: Calls the Apex Calculation Engine when a record is created/updated, saves the deadline to a custom field (`SLA_Deadline__c`), and schedules the actual system notification.
4. **Lightning Web Component (`tat`)**: A frontend UI component placed on the record page that reads the deadline field and displays a live, ticking countdown timer.

---

## 🛠️ Complete Setup Guide

To implement this system for a specific object (e.g., `Lead`), follow these steps in your Salesforce org.

### Step 1: Create the Target Field
You need a field to store the calculated deadline.
1. Go to **Setup** > **Object Manager** > Select your Object (e.g., `Lead`).
2. Go to **Fields & Relationships** > **New**.
3. Type: **Date/Time**
4. Field Label: `SLA Deadline` (API Name: `SLA_Deadline__c`).
5. Save the field and add it to your page layouts if desired.

### Step 2: Configure Business Hours (Dynamic Week-Offs)
Salesforce handles the complex calendar math for you.
1. Go to **Setup** > **Business Hours**.
2. Ensure you have a "Default" record.
3. Create new Business Hours records for different shifts (e.g., "Tuesday-Friday Off"). Uncheck the days that should be considered "week-offs" for that specific shift.

### Step 3: Define Custom Metadata Rules
Tell the system how long the SLA is for different user profiles.
1. Go to **Setup** > **Custom Metadata Types**.
2. Click **Manage Records** next to **TAT Configuration**.
3. Click **New** and configure your rule:
   - **Label**: e.g., `Lead Sales Rep SLA`
   - **Object Name**: `Lead`
   - **Profile Name**: `Sales Rep` *(Leave blank to apply to all profiles)*
   - **SLA Value**: `15`
   - **SLA Unit**: `Minutes` *(Select from: Hours, Minutes, Seconds)*
   - **Business Hours Name**: `Tuesday-Friday Off` *(Must exactly match the name in Step 2)*

### Step 4: (Automated) SLA Calculation
The SLA Calculation is now **100% automated via an Apex Trigger**. You no longer need to create a Record-Triggered Flow to calculate the deadline! 
- The `LeadTrigger` automatically fires `before insert` and `before update`.
- It dynamically queries your Custom Metadata, calculates the deadline based on your Business Hours, and populates `SLA_Deadline__c` instantly.

### Step 5: Schedule the Notification Batch Job
Because we are using 100% Apex, system notifications for SLA breaches are handled by a Scheduled Batch Job.
1. **Create a Notification Type**: Go to **Setup** > **Custom Notifications** > click **New**. Give it a name (e.g., `SLA Breach Notification`) and enable it for Desktop/Mobile.
2. **Schedule the Job**: Go to **Setup** > **Apex Classes** > **Schedule Apex**.
3. **Job Name**: `SLA Expiration Notifier`
4. **Apex Class**: Select `LeadSlaNotificationBatch`
5. **Schedule**: Set it to run Daily. *(Note: To run it more frequently, you must schedule it via the Developer Console using System.schedule).*

### Step 6: Add the Visual Countdown LWC
Show the user how much time they have left.
1. Open a record page (e.g., a Lead) in Salesforce.
2. Click the **Gear Icon** > **Edit Page** to open the Lightning App Builder.
3. Search for **TAT Component** under Custom Components on the left.
4. Drag and drop it onto the page.
5. In the right-hand properties panel, set **SLA Deadline Field API Name** to `SLA_Deadline__c`.
6. Save and Activate the page.

---

## 👨‍💻 Developer Notes

### Component: `tat` (LWC)
- Uses `lightning/uiRecordApi` to dynamically fetch the deadline field without requiring a custom Apex controller.
- Uses standard JavaScript `setInterval` for the countdown logic.
- Target configs in `tat.js-meta.xml` expose the `deadlineFieldApiName` property to the App Builder.

### Component: `TATSlaCalculator` (Apex)
- Bulkified Invocable Method designed for Flows.
- Error handling built-in: If a configuration isn't found, the `hasError` flag is set to true in the `SlaResult` wrapper class.
