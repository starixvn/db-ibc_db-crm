/*<info serverAlias="DBCRM-MessageNotification" ></info>*/
/*
    Created: 20250401@Virgil
    DB: DBCRM-MessageNotification
    Task: MNC - Update alert template for Telegram instead of Skype [RedmineID: #221474]
*/
USE [MessageNotification]
GO

SELECT [TemplateID],
		[TemplateName],
		[Content_en],
		[Content_ch],
		[Content_cs],
		[RequiredParams],
		[CreatorID],
		[CreatedTime],
		[LastModifiedBy],
		[LastModifiedTime],
		[Remark],
		[Content_zhcn]
INTO NotiTemplate_20250401_bk
FROM NotiTemplate WITH(NOLOCK)
WHERE TemplateID IN (7, 8, 9, 10)

-- Alert for Error (Message 1)
UPDATE NotiTemplate WITH(ROWLOCK,UPDLOCK)
SET Content_En = '**RESULT AMENDMENT NOTIFICATION**<br/><br/>Match ID: {MatchID}<br/>Event Date: {EventDate}<br/>Event Time (GMT+8): {KOTime}<br/>League: {LeagueName}<br/>Match: {HomeName} -vs- {AwayName}<br/><br/>Due to an error, the system could not create the new notification. Please pay attention and contact the IT team for further details. Thank you!'
WHERE TemplateID = 7

-- Alert for new Notification created (Message 2)
UPDATE NotiTemplate WITH(ROWLOCK,UPDLOCK)
SET Content_En = '**RESULT AMENDMENT NOTIFICATION**<br/><br/>Please REVIEW and SEND this notification of the following event:<br/><br/>Match ID: {MatchID}<br/>Event Date: {EventDate}<br/>Event Time (GMT+8): {KOTime}<br/>League: {LeagueName}<br/>Match: {HomeName} -vs- {AwayName}<br/><br/>**Notification ID: {NotificationID}**<br/>**Status: NEW**<br/><br/>**English**<br/>{Content_en}<br/><br/>**Traditional Chinese**<br/>{Content_ch}<br/><br/>**Simplified Chinese**<br/>{Content_cs}<br/><br/>**New Simplified Chinese**<br/>{Content_zhcn}'
WHERE TemplateID = 8

-- Alert for inserted failed to DBMSG (Message 3)
UPDATE NotiTemplate WITH(ROWLOCK,UPDLOCK)
SET Content_En = '**RESULT AMENDMENT NOTIFICATION**<br/><br/>Failed to SEND the following notification. Please try to RESEND or contact the IT team for support. Thank you!<br/><br/>Match ID: {MatchID}<br/>Event Date: {EventDate}<br/>Event Time (GMT+8): {KOTime}<br/>League: {LeagueName}<br/>Match: {HomeName} -vs- {AwayName}<br/><br/>**Notification ID: {NotificationID}**<br/>**Status: FAILED**'
WHERE TemplateID = 9

-- Alert for NOT fully generated DBMSG (Message 4)
UPDATE NotiTemplate WITH(ROWLOCK,UPDLOCK)
SET Content_En = '**RESULT AMENDMENT NOTIFICATION**<br/><br/>Match ID: {MatchID}<br/>Event Date: {EventDate}<br/>Event Time (GMT+8): {KOTime}<br/>League: {LeagueName}<br/>Match: {HomeName} -vs- {AwayName}<br/><br/>Due to a technical error, tickets from some sites have not been fully generated. The system is now generating another notification for the affected sites. Please pay attention and contact the IT team for further details. Thank you!'
WHERE TemplateID = 10