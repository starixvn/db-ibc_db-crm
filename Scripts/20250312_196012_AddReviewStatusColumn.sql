/*<info serverAlias="DBBOT-bodb_Chatbot" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20250312@Virgil
	Task: CRM - Manage SMA Feedback in effective way [Redmine #196012]
	DB: DBBOT-bodb_Chatbot
*/

USE bodb_ChatBot
GO

ALTER TABLE [dbo].[CustFeedback]
ADD [ReviewStatusID] INT,
	[Discussion] NVARCHAR(4000);

GO