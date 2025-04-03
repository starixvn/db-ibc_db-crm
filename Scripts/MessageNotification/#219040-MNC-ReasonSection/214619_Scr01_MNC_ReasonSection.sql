/*<info serverAlias="DBCRM-MessageNotification" ></info>*/

/*
    Created: 20250304@Virgil
    DB: DBCRM-MessageNotification
    Task: CRM - Message Notifications Center for Result Amendment - Add Reason [RedmineID: #219040]
*/

USE [MessageNotification]
GO

ALTER TABLE dbo.[Notification]
ADD [ReasonID] INT;

GO
