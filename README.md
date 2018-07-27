# XrmSyncUserAD
Sync Active Directory information with users of Dynamics CRM 2016

This script uses web requests to mimic the initial user creation in Dynamics CRM 2016. It can be run frequently to synchronise active directiory informations like addresses, phone numbers, email adresses, name and title.

Principal email address is excluded from the original script because updating the field cause to desapprove the user email.

I recommend added another filter in the Get-Users function, like do_not_sync. Some development or administrator user might use fake data that you don't want to overwrite.
