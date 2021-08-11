/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/
/*
	Created: 20210811@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #151509]
*/

CREATE TABLE dbo.crmVoidingMessage
(
	MessageId INT,
	MsgTargetId INT,
	BetTransId VARCHAR(MAX),
	CreatedDate	DATETIME,
	IsProcessed	BIT,
	IsChatBotProcessed	BIT,
	IsProcessedUAT	BIT
) ON [DATA]
GO

ALTER TABLE dbo.crmVoidingMessage ADD  CONSTRAINT DF_crmVoidingMessage_IsProcessed  DEFAULT ((0)) FOR [IsProcessed]
GO

ALTER TABLE dbo.crmVoidingMessage ADD  CONSTRAINT DF_crmVoidingMessage_IsChatBotProcessed  DEFAULT ((0)) FOR [IsChatBotProcessed]
GO

ALTER TABLE dbo.crmVoidingMessage ADD  CONSTRAINT DF_crmVoidingMessage_IsProcessedUAT  DEFAULT ((0)) FOR [IsProcessedUAT]
GO
