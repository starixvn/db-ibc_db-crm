/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created by Roy@20240819
	Run at DBCRM@MessageNotification
	Task: UPD NotiTemplate.Content_cs
*/

USE MessageNotification
GO

UPDATE NotiTemplate
SET Content_cs = REPLACE(Content_cs,N'注單:',N'注单:')
WHERE TemplateID BETWEEN 1 AND 5
AND CHARINDEX(N'注單:',Content_cs) > 0

GO
