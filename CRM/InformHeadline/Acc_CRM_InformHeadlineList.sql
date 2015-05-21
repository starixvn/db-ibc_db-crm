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
			CONVERT(VARCHAR(10),it.CreatedDate,120) CreatedDate, 
			COUNT(1) Total,
			s.SettingValue AS Status, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45000 THEN 1 ELSE NULL END) Done,
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45001 THEN 1 ELSE NULL END) RequestToCallBack, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45002 THEN 1 ELSE NULL END) NoNeedToCall, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45003 THEN 1 ELSE NULL END) NoReply, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45004 THEN 1 ELSE NULL END) Uncontactable, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45005 THEN 1 ELSE NULL END) InternalAccount, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45006 THEN 1 ELSE NULL END) NeverTouch,
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45007 THEN 1 ELSE NULL END) KeptForReference
	FROM crmInformTitle_New it WITH (NOLOCK)
		INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON it.TitleID = ih.TitleID
		INNER JOIN crmSetting s WITH (NOLOCK) ON it.StatusID = s.SettingID
	WHERE ih.IsInform = 1
	GROUP BY it.TitleID, it.Title, it.CreatedDate, s.SettingValue 
	ORDER BY it.CreatedDate DESC
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineList] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineList] TO [vnteam]