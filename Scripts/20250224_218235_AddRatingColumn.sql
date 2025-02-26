/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/
/*
    Created: 20259224@Virgil
    DB: DBCRM-bodb_CRM
    Task: CRM - Add Rating Column for Feedback [RedmineID: #218235]
*/
USE [bodb_CRM]
GO

ALTER TABLE [dbo].[crmFeedback]
ADD [Rating] TINYINT NULL CONSTRAINT DF_crmFeedback_Rating DEFAULT 0;

GO


