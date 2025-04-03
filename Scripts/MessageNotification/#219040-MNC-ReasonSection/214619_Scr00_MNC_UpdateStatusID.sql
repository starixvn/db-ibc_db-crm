/*<info serverAlias="DBCRM-MessageNotification" ></info>*/

/*
    Created: 20250402@Virgil
    DB: DBCRM-MessageNotification
    Task: CRM - Update StatusID for Sending NotificationID [RedmineID: #219040]
*/

UPDATE Notification WITH (ROWLOCK, UPDLOCK)
SET StatusID = 13 
WHERE NotificationID = 229