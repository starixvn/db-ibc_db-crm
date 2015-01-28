
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_MainInformationSel    Script Date: 3/26/2014 6:06:08 PM ******/
CREATE PROC Acc_CRM_MainInformationSel
	@CustID INT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	
Param's Explanation:	
*/


-------------------------------------
IF NOT EXISTS(SELECT 1 FROM crmCustomer(NOLOCK) WHERE CustID = @CustID)
BEGIN
	SELECT c.email,
			Passport = NULL,
			c.refcode1 SecretCode,
			ci.credit BetCredit,
			IsVerifyEmail		= 0,
			IsVerifyPassport	= 0,
			IsVerifyBirthday	= 0,
			IsVerifySecretCode	= 0,
			IsVerifyBetCredit	= 0
	FROM bodb02.dbo.Customer(NOLOCK)c
	INNER JOIN bodb02.dbo.custInfo(NOLOCK) ci ON ci.custid = c.custid
	WHERE c.custid = @CustID
END
ELSE
BEGIN
	SELECT c.email,
			c.Passport,
			c.refcode1 SecretCode,
			ci.credit BetCredit,
			IsVerifyEmail = ISNULL(IsVerifyEmail,0) ,
			IsVerifyPassport = ISNULL(IsVerifyPassport,0),
			IsVerifyBirthday = ISNULL(IsVerifyBirthday,0),
			IsVerifySecretCode = ISNULL(IsVerifySecretCode,0),
			IsVerifyBetCredit = ISNULL(IsVerifyBetCredit,0)
	FROM crmCustomer(NOLOCK) c
	INNER JOIN bodb02.dbo.custInfo(NOLOCK) ci ON ci.custid = c.custid
	WHERE c.custid = @CustID
END
-------------------------------------

SELECT TOP 10 Remark FROM crmCustomerRemark(NOLOCK) 
WHERE CustID = @CustID AND IsSpecial = 1

SELECT TOP 10 r.ID RedemptionID,r.Subject,r.ClaimTime,st.Name Status 
FROM crmRedemption(NOLOCK) r
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = r.StatusID
WHERE r.CustID = @CustID

SELECT TOP 10 FeedbackID,
		FeedbackDate,
		mc.Name MainCategory,
		sc.Name SubCategory,
		f.Subject,
		st.Name Status,
		cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
		Creator.username HandleBy,
		Reviewer.username ReviewBy
FROM crmFeedback(nolock) f
INNER JOIN crmMainCategory(NOLOCK) mc ON mc.MainCategoryID = f.MainCategoryID
INNER JOIN crmSubCategory(NOLOCK) sc ON sc.SubCategoryID = f.SubCategoryID
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = f.StatusID
INNER JOIN bodb02.dbo.Customer(NOLOCK) Creator ON Creator.custid = f.CreatorID
INNER JOIN bodb02.dbo.Customer(NOLOCK) Reviewer ON Reviewer.custid = f.ReviewerID
WHERE f.custid = @CustID
AND f.StatusID <> 11004 -- exclude deleted


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_MainInformationSel] TO [vnteam]
GO 
