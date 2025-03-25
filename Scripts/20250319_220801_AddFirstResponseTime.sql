/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/
/*
    Created: 20250319@Virgil
    DB: DBCRM-bodb_CRM
    Task: CRM - Add 1st Reponse Time for Feedback [RedmineID: #220801]
*/
USE [bodb_CRM]
GO

ALTER TABLE [dbo].[crmFeedback]
ADD [FirstResponseTime] DATETIME NULL;

GO
