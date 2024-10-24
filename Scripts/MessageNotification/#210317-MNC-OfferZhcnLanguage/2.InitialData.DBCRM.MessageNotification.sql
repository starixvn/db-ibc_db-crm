/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created: 20240910@Roy
	Task: Initial data for column Content_zhcn
	DB: DBCRM.MessageNotification
	Revisions:
		20240910@Roy: CRM - Offer New Chinese Simplify for Result Amendment of Cricket (MNC) (#210317)
	Steps:
		1. Initial data for Template of Notification.Content_zhcn (TemplateID between 1 and 5)
		2. New Template for [Message 2] - notify a new notification created
*/

USE [MessageNotification]
GO

DECLARE @StarixIT INT
SELECT @StarixIT = TRY_CONVERT(INT, VValue)
FROM SystemSetting WITH (NOLOCK)
WHERE VID = 2 --ID of StarixIT

/***** Template of Notification.Content_zhcn (TemplateID between 1 and 5) ****/
UPDATE NotiTemplate
SET Content_zhcn = Content_cs
	,LastModifiedBy = @StarixIT
	,LastModifiedTime = GETDATE()
WHERE TemplateID BETWEEN 1 AND 5

/***** New Template for [Message 2] - notify a new notification created ****/
UPDATE NotiTemplate
SET Content_en = N'**RESULT AMENDMENT NOTIFICATION**

Please REVIEW and SEND this notification of the following event:

Match ID: {MatchID}
Event Date: {EventDate}
Event Time (GMT+8): {KOTime}
League: {LeagueName}
Match: {HomeName} -vs- {AwayName}

**Notification ID: {NotificationID}**
**Status: NEW**

**English**
{Content_en}

**Traditional Chinese**
{Content_ch}

**Simplified Chinese**
{Content_cs}

**New Simplified Chinese**
{Content_zhcn}'
,RequiredParams = N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID},{Content_en},{Content_cs},{Content_ch},{Content_zhcn}'
WHERE TemplateID = 8