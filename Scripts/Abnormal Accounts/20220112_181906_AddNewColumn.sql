/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20220112@Malcolm
	Task : Add new columm
	DB: DBCRM/bodb_CRM
*/
USE bodb_CRM
GO

ALTER TABLE dbo.crmMessageImport
ADD VoidingHistoryCollectionId INT