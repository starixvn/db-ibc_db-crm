/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_AnnouncementDetail_Sel] @AnnouncementId INT
AS

/*
	Created: 20221213@Malcolm
	Task :  Annoucement - Annoucement list - View detail or edit/clone annoucement
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
        - 20221213@Malcolm: Initialize SPs [Redmine: #179118]
        - 20240327@Ned.Le: CRM - Headline Announcement - Enhancement - Allow to attach separate screenshots for a specific language AND Allow to push Notifications with empty content [Redmine: #201042]
*/

BEGIN
	SET NOCOUNT ON

	;WITH CTE_DirectAccount AS
	(
		SELECT ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX), c.username), ',') WITHIN GROUP (ORDER BY c.username), '') AS DirectAccounts
		FROM dbo.crmAnnouncementDirectAccount cd WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = cd.CustId
		WHERE AnnouncementId = @AnnouncementId
	)
	SELECT 
		a.NotificationTemplateId
		,nt.NotificationTemplateName
		,a.Title
		,a.SiteNameList
		,a.CurrencyIdList
		,a.HeadlineNameList
		,a.HeadlineType
		,a.SendImmediately
		,a.SendDate
		,d.DirectAccounts
	FROM dbo.crmAnnouncement a WITH(NOLOCK)
		LEFT JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateId = a.NotificationTemplateId
		OUTER APPLY CTE_DirectAccount d 
	WHERE a.AnnouncementId = @AnnouncementId

	SELECT 
		SettingID AS LanguageId
		,SettingValue AS LanguageCode
		,ac.Content 
        ,ac.FileName
	FROM dbo.crmSetting l WITH(NOLOCK)
		LEFT JOIN dbo.crmAnnouncementContent ac WITH(NOLOCK) ON ac.AnnouncementId = @AnnouncementId AND ac.LanguageId = l.SettingID
	WHERE SettingID BETWEEN 50000 AND 50004	
END
GO