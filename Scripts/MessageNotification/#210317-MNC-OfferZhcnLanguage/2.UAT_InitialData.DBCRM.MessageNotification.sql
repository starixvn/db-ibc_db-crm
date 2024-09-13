/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
	Created: 20240910@Roy
	Task: Initial data for column Content_zhcn
	DB: DBCRM.MessageNotification
	Revisions:
		20240910@Roy: CRM - Offer New Chinese Simplify for Result Amendment of Cricket (MNC) (#210317)
	Steps:
		1. Initial data for Template of Notification.Content_zhcn (TemplateID between 1 and 5)
		2. Initial data for AlertRule.TemplateTestID
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

/***** TemplateTestID ****/
UPDATE AlertRule
SET TemplateTestID = (CASE WHEN RuleID = 2 THEN 11 ELSE TemplateID END)

/***** New Template for [Message 2] - notify a new notification created ****/
INSERT INTO NotiTemplate (
	TemplateID
	,TemplateName
	,Content_en
	,RequiredParams
	,CreatorID
	,LastModifiedBy
	,Remark
)
VALUES (
		11
		,'TEST version of TemplateID(8) - [Message 2]'
		,N'**RESULT AMENDMENT NOTIFICATION**

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
		,N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID},{Content_en},{Content_cs},{Content_ch},{Content_zhcn}'
		,@StarixIT
		,@StarixIT
		,'TEST version of TemplateID(8) - [Message 2], after completing the tests will be updated to TemplateID=8'
	)