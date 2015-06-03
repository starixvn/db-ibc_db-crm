ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineList]
AS
/*
	Created: Elodie
	Date: 20150331
	Task : get inform headline list
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:	
	
	Param's Explanation:	
*/
BEGIN
	SELECT	it.TitleID, it.Title,
			it.CreatedDate, 
			COUNT(CASE WHEN ih.IsInform = 1 THEN 1 ELSE NULL END) Total,
			s.SettingValue AS Status, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45000 AND ih.IsInform = 1 THEN 1 ELSE NULL END) Done,
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45001 AND ih.IsInform = 1 THEN 1 ELSE NULL END) RequestToCallBack, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45002 AND ih.IsInform = 1 THEN 1 ELSE NULL END) NoNeedToCall, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45003 AND ih.IsInform = 1 THEN 1 ELSE NULL END) NoReply, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45004 AND ih.IsInform = 1 THEN 1 ELSE NULL END) Uncontactable, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45005 AND ih.IsInform = 1 THEN 1 ELSE NULL END) InternalAccount, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45006 AND ih.IsInform = 1 THEN 1 ELSE NULL END) NeverTouch,
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45007 AND ih.IsInform = 1 THEN 1 ELSE NULL END) KeptForReference
	FROM crmInformTitle_New it WITH (NOLOCK)
		INNER JOIN crmSetting s WITH (NOLOCK) ON it.StatusID = s.SettingID
		INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON it.TitleID = ih.TitleID 
	GROUP BY it.TitleID, it.Title, it.CreatedDate, s.SettingValue 
	ORDER BY it.CreatedDate DESC
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineList] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineList] TO [vnteam]