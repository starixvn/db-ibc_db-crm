/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created: 20240910@Roy
	Task: Add new column Content_zhcn
	DB: DBCRM.MessageNotification
	Revisions:
		20240910@Roy: CRM - Offer New Chinese Simplify for Result Amendment of Cricket (MNC) (#210317)
	Steps:
		1. Add new column on Notification
		2. Add new column on NotiTemplate
		2. Add new column on AlertRule
*/

USE MessageNotification
GO

/***** Notification ****/
ALTER TABLE Notification
ADD Content_zhcn NVARCHAR(4000)
GO

/***** NotiTemplate ****/
ALTER TABLE NotiTemplate
ADD Content_zhcn NVARCHAR(4000)
GO

/***** AlertRule ****/
ALTER TABLE AlertRule
ADD TemplateTestID SMALLINT
GO