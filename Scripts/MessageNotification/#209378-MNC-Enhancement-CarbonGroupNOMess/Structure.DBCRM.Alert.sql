/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20240816
	Run at DBCRM@MessageNotification
	Task: Add new column table Alert
*/

USE MessageNotification
GO

ALTER TABLE Alert
ADD IsTest BIT
GO
