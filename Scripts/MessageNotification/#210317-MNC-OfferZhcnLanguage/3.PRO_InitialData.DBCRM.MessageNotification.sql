/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created: 20240910@Roy
	Task: Initial data for column Content_zhcn
	DB: DBCRM.MessageNotification
	Revisions:
		20240910@Roy: CRM - Offer New Chinese Simplify for Result Amendment of Cricket (MNC) (#210317)
	Steps:
		1. Update Content_en for PRO Template after testing
*/

USE [MessageNotification]
GO

/***** Template of Notification.Content_zhcn (TemplateID between 1 and 5) ****/
DECLARE @StarixIT INT
SELECT @StarixIT = TRY_CONVERT(INT, VValue)
FROM SystemSetting WITH (NOLOCK)
WHERE VID = 2 --ID of StarixIT

/***** New Template for [Message 2] - notify a new notification created ****/
UPDATE pro
SET pro.Content_en = uat.Content_en
	,pro.RequiredParams = uat.RequiredParams
	,pro.LastModifiedBy = @StarixIT
	,pro.LastModifiedTime = GETDATE()
FROM NotiTemplate AS uat
	INNER JOIN NotiTemplate AS pro ON uat.TemplateID = 11 AND pro.TemplateID = 8