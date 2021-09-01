/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210831@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #151509]
*/

UPDATE crmVoidingMessage WITH(ROWLOCK)
SET IsChatBotProcessed = 1, IsProcessed = 1, IsProcessedUAT = 1