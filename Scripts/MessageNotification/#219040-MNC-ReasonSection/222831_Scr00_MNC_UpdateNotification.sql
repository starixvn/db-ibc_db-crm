/*<info serverAlias="DBCRM-MessageNotification" ></info>*/

/*
    Created: 20250403@Virgil
    DB: DBCRM-MessageNotification
    Task: CRM - The Message Notifications Center for Result Amendment has been duplicated [RedmineID: #222831]
*/

UPDATE Notification WITH (ROWLOCK, UPDLOCK)
SET LastModifiedTime = '2024-09-25 02:55:50.500' 
WHERE NotificationID = 229
