## List of Scripts
Below are each of the scripts in the repo and what they accomplish.



### InactiveUsers.ps1
  - A PowerShell script that grabs a list of users from Entra ID utilziing MS Graph API. It filters this list based on last sign in date (60 days by default). It then proceeds to create an excel document with these users and their licenses and send an email to any recipient.

### Meraki Monitor.py
  - A Python script that grabs all Meraki devices and checks their status. If it's offline, it will push a Teams notification using webhooks and make a ticket in Atera automatically. Checks every 600 seconds (10 minutes) by default, but can be easily adjusted.
 
