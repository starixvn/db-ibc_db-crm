/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_MainInformationCommunicationLogSel
	@CustID INT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20171225@Winnie:  Change for support multiple product/categories. [RedmineID: #84714]
Param's Explanation:	
*/
BEGIN
	SET ROWCOUNT 10

	SELECT  DISTINCT f.FeedbackID
	INTO #Feedback
	FROM crmFeedback(nolock) f
	LEFT JOIN  crmFeedbackCustomer(NOLOCK) cf ON cf.FeedbackID = f.FeedbackID
	WHERE (f.custid = @CustID OR cf.CustID = @CustID)
	AND f.StatusID <> 11004 -- exclude deleted
	ORDER BY f.FeedbackID DESC

	SELECT f.FeedbackID,
	FeedbackDate,
	f.Subject,
	st.Name Status,
	cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
	Creator.username HandleBy,
	Reviewer.username ReviewBy
	FROM crmFeedback f WITH (NOLOCK)
	INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = f.StatusID
	INNER JOIN bodb02.dbo.Customer(NOLOCK) Creator ON Creator.custid = f.CreatorID
	LEFT JOIN bodb02.dbo.Customer(NOLOCK) Reviewer ON Reviewer.custid = f.ReviewerID
	WHERE f.FeedbackID IN(select feedbackid from #Feedback)
	ORDER BY f.FeedbackID DESC

	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,'Category' 	AS SettingType
	FROM #Feedback fp
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
			ON fs.FeedbackID=fp.FeedbackID	
		INNER JOIN crmMainCategory m 
			ON fs.SettingID=m.MainCategoryID
	DROP TABLE #Feedback

END
GO
 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationCommunicationLogSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_MainInformationCommunicationLogSel] TO [vnteam]
GO 
