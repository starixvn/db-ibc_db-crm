/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_CommunicationLogList
	@CustID INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@StatusID	INT = 0,
	@Handler	VARCHAR(30) = ''
AS
BEGIN
/*
	Created: Dom
	Date: 20140120
	Task : update customer basic info
	DB: DB052.bodb_CRM
	Original:
	
    Revisions:
            - 20180529@Vicky: change the query to use index on DBACC [RedmineID: #95024]
	- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
*/

DECLARE @handlerid int
SELECT @handlerid = CustID
FROM DBACC.bodb02.dbo.Customer WITH (NOLOCK) WHERE UserName = @Handler

	SELECT DISTINCT f.FeedbackID,
			FeedbackDate,
			mc.Name MainCategory,
			sc.Name SubCategory,
			f.Subject,
			st.Name Status,
			cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
			Creator.username HandleBy,
			Reviewer.username ReviewBy
	FROM crmFeedback f WITH(NOLOCK) 
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) ON f.FeedbackID=fs.FeedbackID
		INNER JOIN crmMainCategory mc WITH(NOLOCK)  ON mc.MainCategoryID = fs.SettingID
		INNER JOIN crmSubCategory sc WITH(NOLOCK)  ON sc.SubCategoryID = fs.SubSettingID and sc.MainCategoryID = mc.MainCategoryID
		INNER JOIN crmStatus st WITH(NOLOCK)  ON st.StatusID = f.StatusID
		INNER JOIN bodb02.dbo.Customer Creator WITH(NOLOCK)  ON Creator.custid = f.CreatorID
		LEFT JOIN bodb02.dbo.Customer Reviewer WITH(NOLOCK)  ON Reviewer.custid = f.ReviewerID
	WHERE (f.custid = @CustID )
		AND f.StatusID <> 11004 -- exclude deleted
		AND f.CreateDate BETWEEN @fromdate and @todate 
		AND (isnull(@handler,'')='' OR f.CreatorID = @handlerid)
		AND (isnull(@StatusID,0)=0 OR f.StatusID = @StatusID)
	UNION 
	SELECT DISTINCT f.FeedbackID,
			FeedbackDate,
			mc.Name MainCategory,
			sc.Name SubCategory,
			f.Subject,
			st.Name Status,
			cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
			Creator.username HandleBy,
			Reviewer.username ReviewBy
	FROM crmFeedback f WITH(NOLOCK) 
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) ON f.FeedbackID=fs.FeedbackID
		INNER JOIN crmMainCategory mc WITH(NOLOCK)  ON mc.MainCategoryID = fs.SettingID
		INNER JOIN crmSubCategory sc WITH(NOLOCK)  ON sc.SubCategoryID = fs.SubSettingID and sc.MainCategoryID = mc.MainCategoryID
		INNER JOIN crmStatus st WITH(NOLOCK)  ON st.StatusID = f.StatusID
		INNER JOIN bodb02.dbo.Customer Creator WITH(NOLOCK)  ON Creator.custid = f.CreatorID
		LEFT JOIN bodb02.dbo.Customer Reviewer WITH(NOLOCK)  ON Reviewer.custid = f.ReviewerID
		LEFT JOIN crmFeedbackCustomer cf WITH(NOLOCK)  ON cf.FeedbackID = f.FeedbackID
	WHERE cf.CustID = @CustID
		AND f.StatusID <> 11004 -- exclude deleted
		AND f.CreateDate BETWEEN @fromdate and @todate 
		AND (isnull(@handler,'')='' OR f.CreatorID = @handlerid)
		AND (isnull(@StatusID,0)=0 OR f.StatusID = @StatusID)
	ORDER BY f.FeedbackID DESC
END
GO
