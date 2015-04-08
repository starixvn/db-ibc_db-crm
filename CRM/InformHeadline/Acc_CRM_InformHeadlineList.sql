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
			s.SettingName AS Status, 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45000 THEN 1 ELSE NULL END) Done,
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45001 THEN 1 ELSE NULL END) [Request_to_call_back], 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45002 THEN 1 ELSE NULL END) [No_need_to_call], 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45003 THEN 1 ELSE NULL END) [No_reply], 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45004 THEN 1 ELSE NULL END) [Uncontactable], 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45005 THEN 1 ELSE NULL END) [Internal_account], 
			COUNT(CASE WHEN ih.InformHeadlineStatusID = 45006 THEN 1 ELSE NULL END) [Never_touch]
	FROM crmInformTitle it WITH (NOLOCK)
		INNER JOIN crmInformHeadline ih WITH (NOLOCK) ON it.TitleID = ih.TitleID
		INNER JOIN crmSetting s WITH (NOLOCK) ON it.StatusID = s.SettingID
	GROUP BY it.TitleID, it.Title, CONVERT(VARCHAR(10), it.CreatedDate,120), s.SettingName 
	ORDER BY CONVERT(VARCHAR(10),it.CreatedDate,120) DESC
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineList] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineList] TO [vnteam]