/*<info serverAlias="DBCRM-MessageNotification" ></info>*/

/*
    Created: 20241204@Virgil
    DB: DBCRM-MessageNotification
    Task: CRM - Message Notifications Center - Remark section [RedmineID: #214619]
*/

USE [MessageNotification]
GO

ALTER TABLE dbo.[Notification]
ADD [Remark] NVARCHAR(4000),
	[Filename] NVARCHAR(2000);


ALTER TABLE [dbo].[UserLog]
ADD [NewValue] NVARCHAR(MAX),
	[OldValue] NVARCHAR(MAX);

GO