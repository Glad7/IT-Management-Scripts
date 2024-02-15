# IT-Management-Scripts

### Requirements
  - Both the PowerShell scripts require the ImportExcel module to be installed, alongside Microsoft Graph and ExchangeOnlineManagement
  - The Meraki Monitor script needs the Merakis in Atera to have the serial number attached, so both APIs can communicate with each other. It also needs a Constants.py in the same directory with information found at the top of the program.

### InactiveUsers.ps1
  - This script grabs users and their MS365 licenses, puts them into an Excel document, and then emails it to a recipient of your choosing. Make sure to fill in the sender and recipient email. You will need your own self-signed certificate to authenticate. I would also recommend putting the cert and tenant ID credentials in Windows Credential Manager.

### MailboxUsage.ps1
  - This PowerShell script gets and lists mailboxes >= 80% usage, and the users of those boxes. It stores the information in an Excel document and emails it to a recipient of your choosing.

### Meraki Monitor.py
  - This Python program checks every 10 minutes if a Meraki device is offline. It sends a webhook to MS Teams if so, and creates a ticket in Atera automatically.
