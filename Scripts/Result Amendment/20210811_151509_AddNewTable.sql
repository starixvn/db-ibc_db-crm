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
	BetTransId VARCHAR(MAX)
) ON [DATA]

