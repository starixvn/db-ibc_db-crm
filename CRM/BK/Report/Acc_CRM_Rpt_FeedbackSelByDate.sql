/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackSelByDate]
(
	@FromDate datetime,
	@ToDate datetime
)	
AS
/*
	Created: Kevin
	Date: 20110818
	Task : get feedbacks report by date
	DB: DB06.bodb_CRM
	Original:
	Revisions:
		- 20111126@Sophia: Not to show Status is Pending (StatusID = 11001)		
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON	
	SELECT	@FromDate	= DATEADD(d,0,CONVERT(CHAR(12),@FromDate, 101)),
			@ToDate		= DATEADD(ms,-2,DATEADD(d,1,CONVERT(CHAR(12),@ToDate, 101)))
	;WITH temp AS 
	(
		SELECT t.*, l.list AS relatedCustomer
		FROM (	
				SELECT 
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.MobilePhone, 
					fb.Fax, 
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.CountryID,
					ct.CountryName,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.ProductID, 
					fb.ResponseID, 
					fb.StationID, 
					fb.StatusID, 
					CAST(fb.Description AS XML) AS Description,
					fb.Solution, 
					fb.IsReviewed, 
					rv.username AS ReviewerName,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
						left join crmCountry ct with(nolock) on fb.CountryID = ct.CountryId
				WHERE
					fbc.IsRelated = 0
					AND fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND fb.StatusID NOT IN (11004, 11001)
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		
	)
				SELECT 
					t.FeedbackID, 
					t.CustID, 
					t.UserName,
					t.FirstName, 
					t.LastName, 
					t.Phone, 
					t.MobilePhone, 
					t.Fax, 
					t.Email, 
					t.Skype,
					t.msn,
					t.CountryID,
					t.CountryName,
					t.CreatorID, 
					t.CreatorName,
					t.FeedbackDate,
					t.ResolutionDate,
					t.CreateDate,
					t.SolveDate,
					t.CommunicationID, 
					t.MainCategoryID,
					t.SubCategoryID, 
					t.ProductID, 
					t.ResponseID, 
					t.StationID, 
					t.StatusID, 					
					t.Solution, 
					t.IsReviewed, 
					t.ReviewerName,
					t.Subject,
					nr.value(N'@Remark',N'nvarchar(max)') AS Description
	FROM temp t
	OUTER APPLY t.Description.nodes(N'//row') AS A(nr)
	ORDER BY t.FeedbackDate DESC
END


GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackSelByDate] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackSelByDate] TO [vnteam]