
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_Rpt_FeedbackStatisticDetails    Script Date: 3/26/2014 6:06:09 PM ******/
CREATE PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackStatisticDetails]
(
	@Type			INT,
	@MainCategoryID	INT,
	@SubCategoryID	INT,
	@ValueID		INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@FromDuration	VARCHAR(100),
	@ToDuration		VARCHAR(100)
)
AS
/*
Created: Lukas
Date: 20101204
Task : feedback statistics report
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20110622@Kevin: add new filter: Status, Response, Product, Category
	- 20111011@Lukas: Add filter duration
	- 20120425@Sophia: remove converting @FromDate, @Todate
	- 20140303@Dom: Modify for new structure
Param's Explanation:
	@Type:	- 1		Creator
			- 2		Country
			- 3		Role
			- 4		Site
			- 5		Status
			- 6		Customer Response
			- 7		Product
			- 8		Category
			- 9		Licensee
			- 10	Communication
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @fDuration			INT,
			@tDuration			INT


	DECLARE @tmp TABLE (ID INT IDENTITY PRIMARY KEY, val INT)
	INSERT INTO @tmp(val) SELECT CONVERT(INT,val) FROM dbo.f_split(@FromDuration,':')
	INSERT INTO @tmp(val) SELECT CONVERT(INT,val) FROM dbo.f_split(@ToDuration,':')

	SELECT @fDuration = SUM(CASE WHEN ID = 1 THEN val*24*60*60 
								WHEN ID = 2 THEN val*60*60 
								WHEN ID = 3 THEN val*60 
								WHEN ID = 4 THEN val
								ELSE 0
							END),
		   @tDuration = SUM(CASE WHEN ID = 5 THEN val*24*60*60 
								WHEN ID = 6 THEN val*60*60 
								WHEN ID = 7 THEN val*60 
								WHEN ID = 8 THEN val
								ELSE 0
							END)
	FROM @tmp
	
	IF @fDuration = 0 AND @tDuration = 0
	BEGIN
		SET @tDuration = 2100000000
	END

	IF @Type = 1	--- creator
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode, 
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID,
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,			
					fbc.IsRelated,
					fb.Subject
				FROM
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.CreatorID = @ValueID)
					AND		
					fbc.IsRelated = 0	
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 2    --- Country
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode, 
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,			
					fbc.IsRelated,
					fb.Subject
				FROM
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.CountryID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 3    --- Role
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode, 
					fb.Email,
					fb.Skype,
					fb.msn, 
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,			
					fbc.IsRelated,
					fb.Subject
				FROM
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.RoleID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 4    --- Site
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode, 
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,
					fbc.IsRelated,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.SiteID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 5    --- Status
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode, 
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,			
					fbc.IsRelated,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.StatusID = @ValueID)
					AND		
					fbc.IsRelated = 0	
					AND 
					statusID <> 11004	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 6    --- Customer Response
	BEGIN
		SELECT t.*, l.list relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode,  
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,
					fbc.IsRelated,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					fb.ResponseID = @ValueID
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t	CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 7    --- Product
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode,  
					fb.Email,
					fb.Skype,
					fb.msn, 
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,
					fbc.IsRelated,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.ProductID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 8    --- Category
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode,  
					fb.Email,
					fb.Skype,
					fb.msn, 
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,			
					fbc.IsRelated,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate					
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END
					AND
					(@ValueID=0 OR fb.MainCategoryID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END
	ELSE IF @Type = 9    --- Licensee
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode,  
					fb.Email,
					fb.Skype,
					fb.msn, 
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,
					fbc.IsRelated,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.siteID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC

	END
	ELSE IF @Type = 10    --- communication
	BEGIN
		SELECT t.*, l.list AS relatedCustomer
		FROM (
				SELECT 			
					fb.FeedbackID, 
					fb.CustID, 
					ctm.UserName,
					fb.TitleID, 
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.PhoneAreaCode,
					fb.PhoneCountryCode,
					fb.Phone2, 
					fb.Phone2AreaCode,
					fb.Phone2CountryCode,
					fb.Phone3, 
					fb.Phone3AreaCode,
					fb.Phone3CountryCode,
					fb.MobilePhone, 
					fb.MobilePhoneAreaCode, 
					fb.MobilePhoneCountryCode, 
					fb.Fax, 
					fb.FaxAreaCode, 
					fb.FaxCountryCode,  
					fb.Email,
					fb.Skype,
					fb.msn, 
					fb.LanguageID, 
					fb.CountryID,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.StationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.SiteID, 
					fb.RoleID, 
					fb.ProductID, 
					fb.BetTypeID, 
					fb.ResponseID, 
					fb.StatusID, 
					fb.Description, 
					fb.Solution, 
					fb.IsReviewed, 
					fb.Review, 
					fb.ReviewerID,
					rv.username AS ReviewerName,
					fbc.IsRelated,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 
					MainCategoryID	= CASE WHEN @MainCategoryID = 0 THEN fb.MainCategoryID ELSE @MainCategoryID END
					AND 
					SubCategoryID	= CASE WHEN @SubCategoryID = 0 THEN fb.SubCategoryID ELSE @SubCategoryID END 
					AND
					(@ValueID=0 OR fb.CommunicationID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY t.feedbackdate DESC
	END 
END





GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticDetails] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticDetails] TO [vnteam]
GO 
